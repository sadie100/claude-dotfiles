#!/usr/bin/env node
// Cross-platform Notification hook for Claude Code.
// Reads the Notification event JSON from stdin and dispatches a native
// desktop notification on macOS, Linux, or Windows. Always exits 0 so a
// failure to notify never blocks the Claude session.

import { spawn } from "node:child_process";

const DEFAULT_MESSAGE = "Claude Code needs your attention";
const TITLE = "Claude Code";

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

function parseMessage(raw) {
  if (!raw) return DEFAULT_MESSAGE;
  try {
    const payload = JSON.parse(raw);
    const message = typeof payload?.message === "string" ? payload.message.trim() : "";
    return message || DEFAULT_MESSAGE;
  } catch {
    return DEFAULT_MESSAGE;
  }
}

function fireAndForget(command, args) {
  const child = spawn(command, args, {
    shell: false,
    detached: true,
    stdio: "ignore",
  });
  child.on("error", (err) => {
    process.stderr.write(`[notify] ${command} failed: ${err.message}\n`);
  });
  child.unref();
}

function notifyMac(message) {
  // AppleScript string: escape backslashes and double quotes.
  const escaped = message.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  const script = `display notification "${escaped}" with title "${TITLE}"`;
  fireAndForget("osascript", ["-e", script]);
}

function notifyLinux(message) {
  fireAndForget("notify-send", [TITLE, message]);
}

function notifyWindows(message) {
  // Single-quoted PowerShell strings: escape internal single quotes by doubling them.
  const escaped = message.replace(/'/g, "''");
  const titleEscaped = TITLE.replace(/'/g, "''");
  const psCommand = `[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('${escaped}', '${titleEscaped}')`;
  fireAndForget("powershell.exe", ["-NoProfile", "-Command", psCommand]);
}

async function main() {
  const raw = await readStdin();
  const message = parseMessage(raw);

  try {
    switch (process.platform) {
      case "darwin":
        notifyMac(message);
        break;
      case "linux":
        notifyLinux(message);
        break;
      case "win32":
        notifyWindows(message);
        break;
      default:
        process.stderr.write(`[notify] unsupported platform: ${process.platform}\n`);
    }
  } catch (err) {
    process.stderr.write(`[notify] error: ${err?.message ?? err}\n`);
  }

  process.exit(0);
}

main();
