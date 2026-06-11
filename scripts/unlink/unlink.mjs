#!/usr/bin/env node
// Reverse of install: converts the symlinks install created under ~/.claude
// into standalone real files/dirs, and strips repo-coupled hooks (commands
// referencing DOTCLAUDE_DIR) from the detached settings.json.
//
// This handles the cross-platform file work; the shell wrappers
// (unlink.ps1 / unlink.sh) handle env var + shell-profile cleanup.
//
// Done in node — not PowerShell/python — because Windows PowerShell 5.1's
// ConvertTo-Json collapses single-element arrays to scalars, which would
// corrupt the hooks structure. node is already a hard dependency of this repo.

import {
  lstatSync,
  realpathSync,
  readFileSync,
  writeFileSync,
  unlinkSync,
  cpSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
// scripts/unlink/unlink.mjs -> repo root. Don't trust DOTCLAUDE_DIR: it's
// about to be removed and may be stale.
const REPO_ROOT = resolve(SCRIPT_DIR, "..", "..");
const CLAUDE_DIR = join(homedir(), ".claude");

function isSymlink(p) {
  try {
    return lstatSync(p).isSymbolicLink();
  } catch {
    return false;
  }
}

// Where the symlink actually points; fall back to the repo path.
function sourceOf(target, fallback) {
  try {
    return realpathSync(target);
  } catch {
    return fallback;
  }
}

// Drop hook entries whose command references DOTCLAUDE_DIR (repo-coupled:
// ConfigChange harness-sync, Notification notify.mjs). Prune emptied
// groups/events. Generic hooks (e.g. PostToolUse prettier) are kept.
function stripRepoHooks(hooks) {
  const out = {};
  for (const [event, groups] of Object.entries(hooks)) {
    const keptGroups = [];
    for (const group of Array.isArray(groups) ? groups : [groups]) {
      const keptHooks = (group.hooks || []).filter(
        (h) => !(h.command && h.command.includes("DOTCLAUDE_DIR")),
      );
      if (keptHooks.length > 0) keptGroups.push({ ...group, hooks: keptHooks });
    }
    if (keptGroups.length > 0) out[event] = keptGroups;
  }
  return out;
}

// --- settings.json: real file + repo hooks stripped ---
const settingsTarget = join(CLAUDE_DIR, "settings.json");
if (isSymlink(settingsTarget)) {
  const src = sourceOf(settingsTarget, join(REPO_ROOT, "settings.json"));
  const settings = JSON.parse(readFileSync(src, "utf8"));
  if (settings.hooks) {
    const stripped = stripRepoHooks(settings.hooks);
    if (Object.keys(stripped).length > 0) settings.hooks = stripped;
    else delete settings.hooks;
  }
  unlinkSync(settingsTarget);
  writeFileSync(settingsTarget, JSON.stringify(settings, null, 2) + "\n");
  console.log(`[unlink] ${settingsTarget} (real file, repo hooks stripped)`);
} else {
  console.log(`[skip]   ${settingsTarget} (not a symlink)`);
}

// --- CLAUDE.md: real file ---
const claudeMdTarget = join(CLAUDE_DIR, "CLAUDE.md");
if (isSymlink(claudeMdTarget)) {
  const src = sourceOf(claudeMdTarget, join(REPO_ROOT, "CLAUDE.md"));
  const content = readFileSync(src, "utf8");
  unlinkSync(claudeMdTarget);
  writeFileSync(claudeMdTarget, content);
  console.log(`[unlink] ${claudeMdTarget} (real file)`);
} else {
  console.log(`[skip]   ${claudeMdTarget} (not a symlink)`);
}

// --- skills/ and agents/: real directories ---
for (const dir of ["skills", "agents"]) {
  const target = join(CLAUDE_DIR, dir);
  if (isSymlink(target)) {
    const src = sourceOf(target, join(REPO_ROOT, dir));
    unlinkSync(target); // remove the link only — the repo dir is untouched
    cpSync(src, target, { recursive: true });
    console.log(`[unlink] ${target} (real directory)`);
  } else {
    console.log(`[skip]   ${target} (not a symlink)`);
  }
}
