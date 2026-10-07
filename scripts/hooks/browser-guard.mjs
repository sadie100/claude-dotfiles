#!/usr/bin/env node
// Shared-Chrome browser guard for Claude Code.
// PreToolUse: denies browser tools that disturb the shared debugging Chrome
// (window resize, tab close, extra isolated windows, launch-style servers).
// Stop: blocks a turn that asks the user to log in before trying the
// Chrome-autofilled login form. Any internal error exits 0 silently so the
// session is never broken by this hook.

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

// One isolatedContext name per session: each name opens a new browser window.
function checkIsolatedContext(sessionId, name) {
  const safeId = String(sessionId || "unknown").replace(/[^A-Za-z0-9_-]/g, "_");
  const file = join(STATE_DIR, `${safeId}.json`);
  let stored = "";
  try {
    stored = JSON.parse(readFileSync(file, "utf8"))?.isolatedContext || "";
  } catch {
    // no state yet
  }
  if (!stored) {
    mkdirSync(STATE_DIR, { recursive: true });
    writeFileSync(file, JSON.stringify({ isolatedContext: name }));
    return null;
  }
  if (stored === name) return null;
  return (
    `이 세션은 이미 isolatedContext "${stored}"로 비회원 창을 열었다. ` +
    `isolatedContext마다 새 브라우저 창이 생기므로 "${name}" 같은 다른 이름으로 또 열지 않는다. ` +
    `list_pages로 기존 비회원 탭을 찾아 select_page 후 navigate_page로 재사용할 것.`
  );
}

function preToolUse(payload) {
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
    if (!name) return;
    const reason = checkIsolatedContext(payload.session_id, name);
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

// Concatenated text of the final assistant turn in the transcript (.jsonl).
function lastAssistantText(transcriptPath) {
  try {
    const lines = readFileSync(transcriptPath, "utf8").split("\n");
    const parts = [];
    let seen = false;
    for (let i = lines.length - 1; i >= 0; i--) {
      if (!lines[i]) continue;
      let entry;
      try {
        entry = JSON.parse(lines[i]);
      } catch {
        continue;
      }
      if (entry?.isSidechain) continue;
      if (entry?.type === "assistant") {
        seen = true;
        const content = entry.message?.content;
        const text = Array.isArray(content)
          ? content
              .filter((b) => b?.type === "text" && typeof b.text === "string")
              .map((b) => b.text)
              .join(" ")
          : typeof content === "string"
            ? content
            : "";
        if (text) parts.unshift(text);
        continue;
      }
      // A real user prompt ends the final assistant turn; tool_result entries
      // (type "user" with tool_result content) are part of the turn.
      if (entry?.type === "user" && seen) {
        const c = entry.message?.content;
        const isToolResult = Array.isArray(c) && c.some((b) => b?.type === "tool_result");
        if (!isToolResult) break;
      }
    }
    return parts.join(" ");
  } catch {
    return "";
  }
}

const LOGIN_REQUEST = [
  /로그인(을|해)?\s*(해\s*주|부탁|좀)/,
  /로그인\s*(해|하여)\s*주(세요|시)/,
];
const ESCAPE_TOKEN = "자동완성 로그인 실패";

function stop(payload) {
  if (payload.stop_hook_active) return;
  const text =
    typeof payload.last_assistant_message === "string" && payload.last_assistant_message
      ? payload.last_assistant_message
      : payload.transcript_path
        ? lastAssistantText(payload.transcript_path)
        : "";
  if (!text || text.includes(ESCAPE_TOKEN)) return;
  if (!LOGIN_REQUEST.some((re) => re.test(text))) return;
  process.stdout.write(
    JSON.stringify({
      decision: "block",
      reason:
        "사용자에게 로그인을 부탁하기 전에 직접 시도할 것. 해당 몰의 /member/login.html" +
        "(개발 스킨이면 /skin-skinN/member/login.html)로 이동하면 아이디와 비밀번호가 크롬 자동완성으로 채워져 있으니 " +
        "로그인 버튼만 클릭하고, 쿠키 iscache=F로 회원 여부를 확인한다. " +
        "자동완성이 비어 있거나 로그인이 실패했으면 응답에 '자동완성 로그인 실패'라고 명시하고 그 근거와 함께 부탁할 것.",
    }),
  );
}

async function main() {
  try {
    const raw = await readStdin();
    const payload = JSON.parse(raw);
    if (payload?.hook_event_name === "PreToolUse") preToolUse(payload);
    else if (payload?.hook_event_name === "Stop") stop(payload);
  } catch {
    // never break the session
  }
  process.exit(0);
}

main();
