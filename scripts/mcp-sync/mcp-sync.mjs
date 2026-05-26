#!/usr/bin/env node
// mcp-sync — sync user-scope MCP servers between dotfiles repo and ~/.claude.json
//
// Commands:
//   pull  — repo mcp-servers.json -> ~/.claude.json (merge mcpServers key only,
//           machine values preserved when they exist so tokens aren't wiped).
//           If repo is empty, absorb machine's existing mcpServers into repo
//           (with secrets stripped).
//   sync  — ~/.claude.json mcpServers -> repo mcp-servers.json (secrets stripped).

import { readFileSync, writeFileSync, renameSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import { spawnSync } from "node:child_process";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_DIR = join(SCRIPT_DIR, "..", "..");
const REPO_FILE = join(REPO_DIR, "mcp-servers.json");
const CLAUDE_JSON = join(homedir(), ".claude.json");

const SECRET_KEYS = ["env", "headers", "oauth"];

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function writeJsonAtomic(path, obj) {
  const tmp = `${path}.tmp.${process.pid}`;
  writeFileSync(tmp, JSON.stringify(obj, null, 2) + "\n", "utf8");
  renameSync(tmp, path);
}

function stripSecrets(serverConfig) {
  const out = { ...serverConfig };
  for (const k of SECRET_KEYS) {
    if (k in out) out[k] = {};
  }
  return out;
}

function stripAllSecrets(mcpServers) {
  const out = {};
  for (const [name, cfg] of Object.entries(mcpServers || {})) {
    out[name] = stripSecrets(cfg);
  }
  return out;
}

// Merge repo (base, stripped) into machine (has tokens).
// - Server in machine but not repo: keep machine entry untouched.
// - Server in repo but not machine: add repo entry (empty secrets — user fills in).
// - Server in both: take repo's non-secret fields (command/args/url/type),
//   but preserve machine's secret fields (env/headers/oauth) so tokens aren't wiped.
function mergeIntoMachine(repoServers, machineServers) {
  const result = { ...(machineServers || {}) };
  for (const [name, repoCfg] of Object.entries(repoServers || {})) {
    const machineCfg = result[name];
    if (!machineCfg) {
      result[name] = { ...repoCfg };
      continue;
    }
    const merged = { ...repoCfg };
    for (const k of SECRET_KEYS) {
      const machineVal = machineCfg[k];
      if (machineVal && typeof machineVal === "object" && Object.keys(machineVal).length > 0) {
        merged[k] = machineVal;
      }
    }
    result[name] = merged;
  }
  return result;
}

function loadRepo() {
  if (!existsSync(REPO_FILE)) return { mcpServers: {} };
  const data = readJson(REPO_FILE);
  if (!data.mcpServers || typeof data.mcpServers !== "object") {
    data.mcpServers = {};
  }
  return data;
}

function loadClaudeJson() {
  if (!existsSync(CLAUDE_JSON)) {
    console.error(`[mcp-sync] ${CLAUDE_JSON} not found; skipping.`);
    return null;
  }
  return readJson(CLAUDE_JSON);
}

function cmdPull() {
  const repo = loadRepo();
  const claude = loadClaudeJson();
  if (!claude) return;

  const machineServers = claude.mcpServers || {};
  const repoServers = repo.mcpServers || {};

  const repoEmpty = Object.keys(repoServers).length === 0;
  const machineEmpty = Object.keys(machineServers).length === 0;

  if (repoEmpty && !machineEmpty) {
    // First install: absorb machine's servers into repo (stripped).
    repo.mcpServers = stripAllSecrets(machineServers);
    writeJsonAtomic(REPO_FILE, repo);
    console.log(
      `[mcp-sync] pull (absorb): wrote ${Object.keys(repo.mcpServers).length} server(s) to repo (secrets stripped).`,
    );
    return;
  }

  if (repoEmpty && machineEmpty) {
    console.log("[mcp-sync] pull: nothing to do (both empty).");
    return;
  }

  // Merge repo entries into machine, preserving machine's secret values.
  const merged = mergeIntoMachine(repoServers, machineServers);
  const before = JSON.stringify(machineServers);
  const after = JSON.stringify(merged);
  if (before === after) {
    console.log("[mcp-sync] pull: ~/.claude.json mcpServers already up to date.");
    return;
  }
  claude.mcpServers = merged;
  writeJsonAtomic(CLAUDE_JSON, claude);
  console.log(
    `[mcp-sync] pull: merged ${Object.keys(repoServers).length} repo server(s) into ~/.claude.json.`,
  );
}

function cmdSync() {
  const claude = loadClaudeJson();
  if (!claude) return;
  const machineServers = claude.mcpServers || {};
  const stripped = stripAllSecrets(machineServers);
  const repo = loadRepo();
  const before = JSON.stringify(repo.mcpServers);
  const after = JSON.stringify(stripped);
  if (before === after) {
    console.log("[mcp-sync] sync: repo mcp-servers.json already up to date.");
    return;
  }
  repo.mcpServers = stripped;
  writeJsonAtomic(REPO_FILE, repo);
  console.log(
    `[mcp-sync] sync: wrote ${Object.keys(stripped).length} server(s) to repo (secrets stripped).`,
  );
}

function runHarnessSync() {
  const script = join(SCRIPT_DIR, "..", "harness-sync", "harness-sync.mjs");
  if (!existsSync(script)) return;
  spawnSync("node", [script], { stdio: "inherit" });
}

const cmd = process.argv[2];
switch (cmd) {
  case "pull":
    cmdPull();
    runHarnessSync();
    break;
  case "sync":
    cmdSync();
    runHarnessSync();
    break;
  default:
    console.error("Usage: mcp-sync.mjs <pull|sync>");
    process.exit(1);
}
