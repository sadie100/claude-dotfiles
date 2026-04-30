#!/usr/bin/env node
// Cross-platform dispatcher for dotfiles-sync
// Routes to .ps1 on Windows, .sh on Linux/Mac

import { execFileSync } from "child_process";
import { dirname } from "path";
import { fileURLToPath } from "url";

const dir = dirname(fileURLToPath(import.meta.url));

try {
  if (process.platform === "win32") {
    execFileSync(
      "powershell",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(dir, "dotfiles-sync.ps1")],
      { stdio: "inherit" }
    );
  } else {
    execFileSync("bash", [join(dir, "dotfiles-sync.sh")], { stdio: "inherit" });
  }
} catch {
  // Silently fail — sync is best-effort
}
