#!/usr/bin/env node
// Regenerates auto-managed sections of HARNESS.md.
//
// 1) Computes a fingerprint of (enabledPlugins, hooks). Compares against the
//    `<!-- harness-sync-fingerprint: <hex> -->` comment at the top of HARNESS.md.
//    Same → silent exit. Different (or --force) → continue.
// 2) Collects deterministic data: plugin manifests/skills/agents/commands/mcps/hooks
//    from ~/.claude/plugins/cache, repo-local skills, and settings.json hooks.
// 3) Serializes a JSON payload and pipes it to `claude -p` so an LLM
//    re-renders the markered sections in HARNESS.md.

import { readFileSync, writeFileSync, readdirSync, statSync, existsSync, unlinkSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = process.env.DOTCLAUDE_DIR
  ? resolve(process.env.DOTCLAUDE_DIR)
  : resolve(SCRIPT_DIR, "..", "..");
const PLUGINS_ROOT = join(homedir(), ".claude", "plugins");
const PLUGIN_CACHE = join(PLUGINS_ROOT, "cache");
const MARKETPLACES_DIR = join(PLUGINS_ROOT, "marketplaces");
const HARNESS_PATH = join(REPO_ROOT, "HARNESS.md");
const SETTINGS_PATH = join(REPO_ROOT, "settings.json");
const GLOBAL_CLAUDE_MD = join(homedir(), ".claude", "CLAUDE.md");

const FORCE = process.argv.includes("--force");
const SECTION_IDS = ["plugins", "skills", "hooks"];
const LOCK_FILE = join(REPO_ROOT, ".git", "harness-sync.lock");
const DIRTY_FILE = join(REPO_ROOT, ".git", "harness-sync.dirty");

// ---------- utilities ----------

function readJsonSafe(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

function readTextSafe(path) {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return null;
  }
}

function lsDirs(path) {
  try {
    return readdirSync(path, { withFileTypes: true })
      .filter((d) => d.isDirectory() || d.isSymbolicLink())
      .map((d) => d.name);
  } catch {
    return [];
  }
}

function lsFiles(path) {
  try {
    return readdirSync(path, { withFileTypes: true })
      .filter((d) => d.isFile())
      .map((d) => d.name);
  } catch {
    return [];
  }
}

function pickLatestVersionDir(parentDir) {
  const subs = lsDirs(parentDir);
  if (subs.length === 0) return null;
  let best = null;
  let bestMtime = -1;
  for (const sub of subs) {
    try {
      const m = statSync(join(parentDir, sub)).mtimeMs;
      if (m > bestMtime) {
        bestMtime = m;
        best = sub;
      }
    } catch {
      /* ignore */
    }
  }
  return best ? join(parentDir, best) : null;
}

// Minimal YAML frontmatter parser. Handles simple `key: value` lines and
// block scalars (`key: >` folded / `key: |` literal) with indented continuations.
function parseFrontmatter(content) {
  if (!content) return {};
  const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return {};
  const fields = {};
  const lines = m[1].split(/\r?\n/);
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    const kv = line.match(/^([A-Za-z][\w-]*)\s*:\s*(.*)$/);
    if (!kv) {
      i++;
      continue;
    }
    const key = kv[1];
    let val = kv[2].trim();
    if (val === ">" || val === "|" || val === ">-" || val === "|-") {
      const literal = val.startsWith("|");
      const parts = [];
      i++;
      while (i < lines.length) {
        const next = lines[i];
        if (/^\S/.test(next)) break;
        parts.push(next.replace(/^\s+/, ""));
        i++;
      }
      val = literal ? parts.join("\n").trim() : parts.join(" ").trim();
    } else {
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      i++;
    }
    fields[key] = val;
  }
  return fields;
}

// ---------- fingerprint ----------

function stableStringify(value) {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) {
    return "[" + value.map(stableStringify).join(",") + "]";
  }
  const keys = Object.keys(value).sort();
  return "{" + keys.map((k) => JSON.stringify(k) + ":" + stableStringify(value[k])).join(",") + "}";
}

function computeFingerprint(settings, localSkills) {
  const payload = {
    enabledPlugins: settings.enabledPlugins ?? {},
    hooks: settings.hooks ?? {},
    localSkills: [...localSkills].sort((a, b) => a.name.localeCompare(b.name)),
  };
  return createHash("sha256").update(stableStringify(payload)).digest("hex");
}

const FP_RE = /<!--\s*harness-sync-fingerprint:\s*([0-9a-f]*)\s*-->/i;

function readStoredFingerprint(harness) {
  const m = harness.match(FP_RE);
  return m ? m[1] : "";
}

function writeStoredFingerprint(harness, hex) {
  const tag = `<!-- harness-sync-fingerprint: ${hex} -->`;
  if (FP_RE.test(harness)) return harness.replace(FP_RE, tag);
  // Insert after the first line (title).
  const lines = harness.split(/\r?\n/);
  lines.splice(1, 0, "", tag);
  return lines.join("\n");
}

// ---------- plugin discovery ----------

function enumeratePluginKeys(settings) {
  const result = [];
  for (const [key, enabled] of Object.entries(settings.enabledPlugins ?? {})) {
    const at = key.lastIndexOf("@");
    if (at < 0) continue;
    result.push({
      key,
      plugin: key.slice(0, at),
      marketplace: key.slice(at + 1),
      enabled: !!enabled,
    });
  }
  return result.sort((a, b) =>
    a.marketplace === b.marketplace
      ? a.plugin.localeCompare(b.plugin)
      : a.marketplace.localeCompare(b.marketplace),
  );
}

function loadMarketplaceManifests() {
  const out = {};
  for (const name of lsDirs(MARKETPLACES_DIR)) {
    const manifest = readJsonSafe(join(MARKETPLACES_DIR, name, ".claude-plugin", "marketplace.json"));
    if (manifest) out[name] = manifest;
  }
  return out;
}

function findPluginDir(marketplace, plugin) {
  return pickLatestVersionDir(join(PLUGIN_CACHE, marketplace, plugin));
}

function findSkillRoots(pluginDir) {
  return [
    join(pluginDir, "skills"),
    join(pluginDir, ".claude", "skills"),
    join(pluginDir, "src", "skills"),
  ].filter((p) => existsSync(p));
}

function collectSkillsFromRoot(skillsRoot) {
  const out = [];
  for (const dir of lsDirs(skillsRoot)) {
    const content = readTextSafe(join(skillsRoot, dir, "SKILL.md"));
    if (!content) continue;
    const fm = parseFrontmatter(content);
    out.push({ name: fm.name || dir, description: fm.description || "" });
  }
  return out;
}

function collectPluginSkills(pluginDir) {
  const out = [];
  for (const r of findSkillRoots(pluginDir)) out.push(...collectSkillsFromRoot(r));
  return out;
}

function collectPluginAgents(pluginDir) {
  const dir = join(pluginDir, "agents");
  if (!existsSync(dir)) return [];
  const out = [];
  for (const file of lsFiles(dir)) {
    if (!file.endsWith(".md")) continue;
    const content = readTextSafe(join(dir, file));
    if (!content) continue;
    const fm = parseFrontmatter(content);
    out.push({ name: fm.name || file.replace(/\.md$/, ""), description: fm.description || "" });
  }
  return out;
}

function collectPluginCommands(pluginDir) {
  const dir = join(pluginDir, "commands");
  if (!existsSync(dir)) return [];
  const out = [];
  for (const file of lsFiles(dir)) {
    if (!file.endsWith(".md")) continue;
    const content = readTextSafe(join(dir, file));
    if (!content) continue;
    const fm = parseFrontmatter(content);
    out.push({ name: file.replace(/\.md$/, ""), description: fm.description || "" });
  }
  return out;
}

function collectPluginMcps(pluginDir) {
  const cfg = readJsonSafe(join(pluginDir, ".mcp.json"));
  if (!cfg) return [];
  const servers = cfg.mcpServers && typeof cfg.mcpServers === "object" ? cfg.mcpServers : cfg;
  return Object.entries(servers).map(([name, def]) => ({
    name,
    command: def?.command ? `${def.command} ${(def.args ?? []).join(" ")}`.trim() : "",
  }));
}

function collectPluginHooks(pluginDir) {
  const cfg = readJsonSafe(join(pluginDir, "hooks", "hooks.json"));
  if (!cfg || !cfg.hooks || typeof cfg.hooks !== "object") return [];
  const out = [];
  for (const [event, groups] of Object.entries(cfg.hooks)) {
    if (!Array.isArray(groups)) continue;
    for (const g of groups) {
      for (const h of g.hooks ?? []) {
        out.push({ event, command: h.command ?? "", type: h.type ?? "" });
      }
    }
  }
  return out;
}

function loadPluginManifest(pluginDir) {
  return readJsonSafe(join(pluginDir, ".claude-plugin", "plugin.json")) ?? {};
}

function descriptionFromMarketplace(manifests, marketplace, plugin) {
  const m = manifests[marketplace];
  if (!m || !Array.isArray(m.plugins)) return "";
  const entry = m.plugins.find((p) => p.name === plugin);
  return entry?.description ?? "";
}

function collectLocalSkills() {
  const skillsDir = join(REPO_ROOT, "skills");
  const out = [];
  for (const dir of lsDirs(skillsDir)) {
    const content = readTextSafe(join(skillsDir, dir, "SKILL.md"));
    if (!content) continue;
    const fm = parseFrontmatter(content);
    out.push({ name: fm.name || dir, description: fm.description || "" });
  }
  return out;
}

function collectRepoHooks(settings) {
  const out = [];
  for (const [event, groups] of Object.entries(settings.hooks ?? {})) {
    if (!Array.isArray(groups)) continue;
    for (const g of groups) {
      for (const h of g.hooks ?? []) {
        out.push({
          event,
          type: h.type ?? "",
          command: h.command ?? "",
          mode: h.async ? "async" : "sync",
          source: "settings.json",
        });
      }
    }
  }
  return out;
}

// ---------- claude -p invocation ----------

const PROMPT_TEMPLATE = `너는 이 레포의 HARNESS.md 자동 생성 섹션을 갱신하는 작업을 한다.

## 입력 데이터
아래 JSON은 결정적 스크립트가 수집한 현재 상태이다 (플러그인 / 스킬 / 훅).

\`\`\`json
__PAYLOAD__
\`\`\`

새 fingerprint hex: __FINGERPRINT__

## 작업
1. HARNESS.md를 Read 도구로 읽는다.
2. 다음 markered 구역만 Edit으로 교체한다. 다른 곳(인트로, 마커 외부)은 절대 건드리지 말 것.
   - \`<!-- AUTO:BEGIN plugins -->\` ... \`<!-- AUTO:END plugins -->\`
   - \`<!-- AUTO:BEGIN skills -->\` ... \`<!-- AUTO:END skills -->\`
   - \`<!-- AUTO:BEGIN hooks -->\` ... \`<!-- AUTO:END hooks -->\`
3. 최상단의 \`<!-- harness-sync-fingerprint: ... -->\` 주석을 새 값(__FINGERPRINT__)으로 갱신.
4. 모든 마커(BEGIN/END 쌍)는 그대로 유지. 한 줄도 빠뜨리면 안 됨.

## 작성 스타일 (기존 HARNESS.md 톤 유지)
- **한국어**, 카테고리화된 마크다운 표 형식.
- **플러그인 섹션**: 마켓플레이스별로 \`### \\\`<marketplace>\\\`\` 헤더 + 표 (플러그인 / 상태(✅/❌) / 설명).
  - 설명은 manifest.description → marketplaceDescription 순으로 우선. 영어면 핵심을 1줄 한글로 의역.
- **스킬 섹션**: 도메인별로 \`### <도메인명>\` 헤더 + 표 (스킬 / 트리거 / 소속 / 설명).
  - 도메인 예시: 개발 프로세스 / 문서·스펙 작성 / 브라우저 테스트·검증 / 코드 리뷰·품질 / UI·디자인 생성 / 문서 포맷 생성 / Slack 연동 / Notion 연동 / Atlassian 연동 / Superpowers / CLAUDE.md·스킬 관리 / Claude API·MCP 빌드 / 환경·설정.
  - 소속: 로컬 스킬은 \`custom\`, 플러그인 스킬은 플러그인 이름.
  - 트리거: 슬래시 커맨드면 \`\\\`/name\\\`\`, 아니면 "<상황> 시" 형태.
  - 비활성 플러그인의 스킬은 제외.
- **훅 섹션**: 표 (이벤트 / 실행 명령 / 비동기 / 설명). 설명은 명령에서 추론한 1줄 한글.

## 출력
- HARNESS.md를 Edit으로 직접 수정한 뒤 작업 종료.
- 추가 설명 텍스트는 출력하지 말 것.
`;

function buildPrompt(payload, fingerprint) {
  return PROMPT_TEMPLATE
    .replace("__PAYLOAD__", JSON.stringify(payload, null, 2))
    .replaceAll("__FINGERPRINT__", fingerprint);
}

function runClaude(prompt) {
  const args = [
    "-p",
    "--permission-mode", "acceptEdits",
    "--allowed-tools", "Read Edit Write Glob Grep",
    "--model", "opus",
    "--add-dir", REPO_ROOT,
  ];
  const result = spawnSync("claude", args, {
    input: prompt,
    encoding: "utf8",
    stdio: ["pipe", "inherit", "inherit"],
    shell: process.platform === "win32",
  });
  if (result.error) {
    process.stderr.write(`harness-sync: failed to spawn claude: ${result.error.message}\n`);
    return false;
  }
  if (result.status !== 0) {
    process.stderr.write(`harness-sync: claude exited with code ${result.status}\n`);
    return false;
  }
  return true;
}

function runDotfilesSync() {
  const script = join(REPO_ROOT, "scripts", "dotfiles-sync", "dotfiles-sync.mjs");
  spawnSync("node", [script], { stdio: "inherit" });
}

// ---------- concurrency: lock + dirty flag + rerun loop ----------

function isProcessAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    // EPERM means the process exists but we lack permission (still alive).
    return err.code === "EPERM";
  }
}

function tryAcquireLock() {
  try {
    writeFileSync(LOCK_FILE, String(process.pid), { flag: "wx" });
    return true;
  } catch {
    const stale = readFileSync(LOCK_FILE, "utf8").trim();
    const stalePid = Number.parseInt(stale, 10);
    if (!isProcessAlive(stalePid)) {
      try { unlinkSync(LOCK_FILE); } catch {}
      try {
        writeFileSync(LOCK_FILE, String(process.pid), { flag: "wx" });
        return true;
      } catch {}
    }
    return false;
  }
}

function releaseLock() {
  try { unlinkSync(LOCK_FILE); } catch {}
}

function markDirty() {
  try { writeFileSync(DIRTY_FILE, ""); } catch {}
}

function consumeDirty() {
  try {
    unlinkSync(DIRTY_FILE);
    return true;
  } catch {
    return false;
  }
}

function sanityCheckMarkers(harness) {
  for (const id of SECTION_IDS) {
    const begin = `<!-- AUTO:BEGIN ${id} -->`;
    const end = `<!-- AUTO:END ${id} -->`;
    if (!harness.includes(begin) || !harness.includes(end)) {
      process.stderr.write(`harness-sync: marker '${id}' missing after claude run\n`);
      return false;
    }
  }
  return true;
}

// ---------- main ----------

function main() {
  const settings = readJsonSafe(SETTINGS_PATH);
  if (!settings) {
    process.stderr.write(`harness-sync: cannot read ${SETTINGS_PATH}\n`);
    return;
  }
  const harnessBefore = readTextSafe(HARNESS_PATH);
  if (harnessBefore == null) {
    process.stderr.write(`harness-sync: cannot read ${HARNESS_PATH}\n`);
    return;
  }

  const localSkills = collectLocalSkills();
  const newFingerprint = computeFingerprint(settings, localSkills);
  const oldFingerprint = readStoredFingerprint(harnessBefore);

  if (!FORCE && newFingerprint === oldFingerprint) {
    return; // no-op
  }

  const manifests = loadMarketplaceManifests();
  const pluginEntries = enumeratePluginKeys(settings);
  const plugins = [];
  for (const e of pluginEntries) {
    const pluginDir = findPluginDir(e.marketplace, e.plugin);
    plugins.push({
      key: e.key,
      name: e.plugin,
      marketplace: e.marketplace,
      enabled: e.enabled,
      manifest: pluginDir ? loadPluginManifest(pluginDir) : null,
      marketplaceDescription: descriptionFromMarketplace(manifests, e.marketplace, e.plugin),
      skills: pluginDir ? collectPluginSkills(pluginDir) : [],
      agents: pluginDir ? collectPluginAgents(pluginDir) : [],
      commands: pluginDir ? collectPluginCommands(pluginDir) : [],
      mcps: pluginDir ? collectPluginMcps(pluginDir) : [],
      hooks: pluginDir ? collectPluginHooks(pluginDir) : [],
    });
  }

  const payload = {
    marketplaces: Object.fromEntries(
      Object.entries(manifests).map(([k, v]) => [k, { description: v.description ?? "" }]),
    ),
    extraKnownMarketplaces: settings.extraKnownMarketplaces ?? {},
    plugins,
    localSkills,
    repoHooks: collectRepoHooks(settings),
    globalInstructions: readTextSafe(GLOBAL_CLAUDE_MD) ?? "",
  };

  const prompt = buildPrompt(payload, newFingerprint);
  const ok = runClaude(prompt);
  if (!ok) return;

  const harnessAfter = readTextSafe(HARNESS_PATH);
  if (harnessAfter == null) {
    process.stderr.write(`harness-sync: HARNESS.md missing after claude run\n`);
    return;
  }
  if (!sanityCheckMarkers(harnessAfter)) {
    writeFileSync(HARNESS_PATH, harnessBefore, "utf8");
    process.stderr.write(`harness-sync: rolled back HARNESS.md due to marker damage\n`);
    return;
  }
  // Ensure fingerprint comment is in sync even if claude forgot to update it.
  const stored = readStoredFingerprint(harnessAfter);
  if (stored !== newFingerprint) {
    writeFileSync(HARNESS_PATH, writeStoredFingerprint(harnessAfter, newFingerprint), "utf8");
  }
}

if (!tryAcquireLock()) {
  // Another harness-sync is running. Leave a dirty marker so it reruns,
  // and bail out fast so the ConfigChange hook doesn't block.
  markDirty();
  process.exit(0);
}

try {
  // Rerun loop: if anyone marks dirty while we're working, do another pass.
  // Consume the marker *before* each pass so a marker set during the pass
  // triggers exactly one more round, not an infinite loop.
  let safety = 5;
  do {
    consumeDirty();
    try {
      main();
    } catch (err) {
      process.stderr.write(`harness-sync: ${err?.stack ?? err}\n`);
    }
    runDotfilesSync();
  } while (consumeDirty() && --safety > 0);
} finally {
  releaseLock();
}
