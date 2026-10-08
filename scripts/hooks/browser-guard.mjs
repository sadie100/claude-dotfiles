#!/usr/bin/env node
// Shared-Chrome browser guard for Claude Code.
// PreToolUse: denies browser tools that disturb the shared debugging Chrome
// (window resize, tab close, extra isolated windows, unchecked new tabs, launch-style servers).
// Any internal error exits 0 silently so the session is never broken by this hook.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const CDP = "mcp__chrome-devtools-shared__";
const PW = "mcp__playwright-shared__";
const STATE_DIR = join(homedir(), ".claude", "state", "browser-guard");

function readStdin() {
  return new Promise((resolve) => {
    if (process.stdin.isTTY) {
      resolve("");
      return;
    }
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => (data += chunk));
    process.stdin.on("end", () => resolve(data));
    process.stdin.on("error", () => resolve(data));
  });
}

function deny(reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: reason,
      },
    }),
  );
}

function stateFile(sessionId) {
  const safeId = String(sessionId || "unknown").replace(/[^A-Za-z0-9_-]/g, "_");
  return join(STATE_DIR, `${safeId}.json`);
}

function readState(sessionId) {
  try {
    return JSON.parse(readFileSync(stateFile(sessionId), "utf8")) || {};
  } catch {
    return {};
  }
}

function writeState(sessionId, state) {
  mkdirSync(STATE_DIR, { recursive: true });
  writeFileSync(stateFile(sessionId), JSON.stringify(state));
}

// One isolatedContext name per session: each name opens a new browser window.
function checkIsolatedContext(sessionId, name) {
  const state = readState(sessionId);
  const stored = state.isolatedContext || "";
  if (!stored) {
    writeState(sessionId, { ...state, isolatedContext: name });
    return null;
  }
  if (stored === name) return null;
  return (
    `이 세션은 이미 isolatedContext "${stored}"로 비회원 창을 열었다. ` +
    `isolatedContext마다 새 브라우저 창이 생기므로 "${name}" 같은 다른 이름으로 또 열지 않는다. ` +
    `list_pages로 기존 비회원 탭을 찾아 select_page 후 navigate_page로 재사용할 것.`
  );
}

// Tabs in the shared Chrome on the same host as the URL about to be opened.
async function sameHostTabs(url) {
  let host = "";
  try {
    host = new URL(url).host;
  } catch {
    return [];
  }
  try {
    const res = await fetch("http://127.0.0.1:9222/json/list", { signal: AbortSignal.timeout(800) });
    const list = await res.json();
    return list
      .filter((t) => t.type === "page")
      .filter((t) => {
        try {
          return new URL(t.url).host === host;
        } catch {
          return false;
        }
      })
      .map((t) => t.url);
  } catch {
    return [];
  }
}

// Think-before-new-tab gate: when tabs on the same host already exist, deny the first
// new_page once (per session and host, re-armed after 10 min) so the agent checks them first.
// Repeating the same call afterwards passes — that is the deliberate "I checked" path.
const NEW_PAGE_WARN_TTL = 10 * 60 * 1000;

async function checkNewPage(sessionId, url) {
  const tabs = await sameHostTabs(url);
  if (tabs.length === 0) return null;
  let host = "";
  try {
    host = new URL(url).host;
  } catch {
    return null;
  }
  const state = readState(sessionId);
  const warned = state.newPageWarned || {};
  if (warned[host] && Date.now() - warned[host] < NEW_PAGE_WARN_TTL) return null;
  writeState(sessionId, { ...state, newPageWarned: { ...warned, [host]: Date.now() } });
  return (
    `새 탭을 열기 전에 멈춘다. 공유 크롬에 ${host} 탭이 이미 ${tabs.length}개 있다:\n` +
    tabs.map((u) => `  - ${u}`).join("\n") +
    `\n한 세션은 회원 탭 1개, 비회원 탭 1개까지만 둔다. 다음을 먼저 할 것:\n` +
    `  1. list_pages로 위 탭의 pageId를 찾는다.\n` +
    `  2. 각 탭에서 쿠키 iscache=F를 읽어 회원/비회원을 판정한다(라벨·isolatedContext 이름으로 단정 금지).\n` +
    `  3. 필요한 상태의 탭이 있으면 그 탭에서 navigate_page 한다(URL이 달라도 새로 열지 않는다).\n` +
    `확인한 결과 쓸 수 있는 탭이 정말 없을 때만 같은 new_page를 다시 호출한다(그때는 통과). ` +
    `사용자에게 왜 새 탭이 필요한지 한 줄로 알린다.`
  );
}

async function preToolUse(payload) {
  const tool = String(payload.tool_name || "");
  const input = payload.tool_input || {};

  if (tool === `${CDP}resize_page` || tool === `${PW}browser_resize`) {
    return deny(
      "공유 크롬의 OS 창 크기를 바꾸므로 금지. 반응형 확인은 emulate(viewport)로 탭 안에서만 에뮬레이션할 것.",
    );
  }
  if (tool === `${CDP}close_page` || tool === `${PW}browser_close`) {
    return deny(
      "검증 탭은 사용자가 이어서 확인하므로 닫지 않는다. 재검증은 기존 탭에서 navigate 할 것.",
    );
  }
  if (tool === `${CDP}new_page`) {
    const name = typeof input.isolatedContext === "string" ? input.isolatedContext.trim() : "";
    const isoReason = name ? checkIsolatedContext(payload.session_id, name) : null;
    if (isoReason) return deny(isoReason);
    const reason = await checkNewPage(payload.session_id, String(input.url || ""));
    if (reason) deny(reason);
    return;
  }
  if (
    tool.startsWith("mcp__claude-in-chrome__") ||
    tool.startsWith("mcp__plugin_chrome-devtools-mcp_chrome-devtools__")
  ) {
    return deny(
      "공유 크롬 attach 서버(chrome-devtools-shared / playwright-shared)만 사용한다. " +
        "공유 서버가 실패하면 다른 브라우저 서버로 우회하지 말고 사용을 중단한 뒤 사용자에게 보고할 것(이 훅 해제는 사용자 결정).",
    );
  }
}

async function main() {
  try {
    const raw = await readStdin();
    const payload = JSON.parse(raw);
    if (payload?.hook_event_name === "PreToolUse") await preToolUse(payload);
  } catch {
    // never break the session
  }
  process.exit(0);
}

main();
