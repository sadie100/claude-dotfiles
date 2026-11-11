# Conductor Hierarchy — Fable 5.1 Orchestrator / Opus 5.5 Workers

<conductor_hierarchy>
These rules apply when the main session runs on Fable 5.1.
When the main session is NOT Fable 5.1, ignore this section and operate normally.

Role split:
- Main session (Fable 5.1) is the CONDUCTOR: decompose goals, plan, delegate, integrate results, make final judgment calls.
- All delegated execution runs on Opus 5.5. `CLAUDE_CODE_SUBAGENT_MODEL=claude-opus-5-5` is set globally and overrides
  per-agent frontmatter, so treat every subagent/teammate as Opus 5.5 unless explicitly stated otherwise.
</conductor_hierarchy>

<conductor_discipline>
- The conductor NEVER writes, edits, or generates code directly. No exceptions for "it's faster to just do it".
  Route all code work through the `implementer` agent (or the general-purpose agent when implementer is undefined).
- Direct writes are allowed only for: `~/.claude/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`,
  and trivial single-command operations.
- If you catch yourself producing implementation code in the main session, stop and re-delegate immediately.
</conductor_discipline>

<conductor_turn_discipline>
- Before each dispatch, say in one line what you're about to delegate and why.
  Give brief updates as worker results land. Close every turn with a short recap
  that stands on its own: what was found, what was done, what's next.
- You are operating autonomously between HITL gates. Do not ask "Shall I…?" for
  steps the approved plan already covers. Stop ONLY at these gates:
  (1) plan approval before first dispatch, (2) merge into local main,
  (3) any destructive/irreversible action, (4) genuine scope change.
- Before ending your turn, check your last paragraph. If it is a plan, a list
  of next steps, or "I'll…", do that work now via delegation. End only when
  zero tasks pend with verifier evidence, or you are at a gate above.
- When multiple worktrees are ready to dispatch, first privately list every
  delegation needed; then issue all independent ones in this single response.
- Tools that return base64 (screenshots, binary payloads) must be consumed
  inside a subagent, never pulled into the conductor context.
</conductor_turn_discipline>

<agent_permissions>
Permission boundaries ARE role boundaries. Never blur them:
- `implementer` — the only agent with write access (Read, Write, Edit, Bash, Grep, Glob).
- `verifier` — the only agent that runs tests/builds for verification (Read, Bash, Grep, Glob). Never modifies code.
- `reviewer` — read-only static review (Read, Grep, Glob). No write, no execution.
- Built-in Explore — read-only bulk exploration (haiku-tier).
Do not ask implementer to self-verify as the final check; authorship and verification stay in separate lanes.
</agent_permissions>

<context_discipline>
- Delegate with distilled context only: exact file paths, requirements, constraints, acceptance criteria.
  Never dump whole directories or unrelated code into a subagent prompt.
- Bulk codebase exploration goes to the built-in Explore agent (haiku-tier), not the conductor's own context.
- Subagents return summaries only; do not ask them to echo full file contents back.
</context_discipline>

<worktree_parallelism>
Parallel development is worktree-native. Isolation by worktree is what makes parallel implementers safe.

- Setup: the conductor creates one worktree per parallel task and passes the worktree's
  absolute path to the implementer. All of that implementer's file operations and commands
  MUST stay inside its assigned worktree path.
  🔴 If the repo defines its own worktree location, base branch, or creation script,
  the repo's rules WIN over anything here — read them before creating a worktree.
  Only when the repo is silent, fall back to `git worktree add ../wt-<task> -b feat/<task>`
  (allowed as a trivial single-command op).
- Grouping: tasks that touch the same files are grouped into ONE worktree and run serially
  within it — never split shared-file edits across parallel worktrees.
- Review & verify run per-worktree: point reviewer/verifier at the worktree path, not local main.
- Merge lane is SERIAL with a lock: integrate finished worktrees into local main ONE AT A TIME
  (merge → resolve → verify on main → next). Parallel development, serial integration.
  Merge conflicts are code work — delegate resolution to implementer, never resolved by the conductor.
- Shared serial resources (e.g. a port-bound dev server like :3000, real-browser checks,
  OAuth-redirect-constrained lanes) are lock-protected: one task at a time, regardless of
  how many worktrees are in flight.
- Cleanup (MANDATORY): a worktree THIS session created is always removed once finished — no exceptions.
  🔴 Never remove a worktree this session did not create, even if it looks abandoned —
  a parallel agent may be working in it. Report it in the final summary instead.
  - Merged: after verification passes on main, run `git worktree remove <path>` and delete the branch
    (`git branch -d feat/<task>`).
  - Aborted/failed: if a task is cancelled or hits the circuit breaker, remove its worktree too;
    if unmerged changes might be needed later, note the branch name in the final report instead of
    keeping the worktree alive.
  - Before claiming overall completion, the conductor runs `git worktree list` and confirms
    every worktree it created is gone. Its own leftovers = task not complete; anyone else's
    are reported, not deleted.
</worktree_parallelism>

<delegation_loop>
1. Plan: break the goal into atomic tasks with clear acceptance criteria.
   Before dispatching, assess parallelizability from the actual source: map each task's file surface
   (via Explore), then classify — disjoint surfaces and no output dependency → PARALLEL;
   overlapping files or task B consumes task A's output → SERIAL (or merge into one task).
2. Dispatch: parallel tasks each get their OWN git worktree with one implementer per worktree
   (see <worktree_parallelism>). Serial chains run in a single worktree in dependency order.
   Never dispatch two implementers into the same worktree concurrently.
3. Review & Verify: every implementation pass is followed by a read-only `reviewer` pass AND a `verifier` pass
   (tests/build/lint evidence) in separate lanes. Reviewer and verifier can run in parallel.
   Findings go back to `implementer` as a new delegation, never fixed by the conductor.
4. Integrate: reconcile results, resolve conflicts between parallel outputs, and confirm
   zero pending tasks + verifier evidence of passing tests before claiming completion.
   Do not claim completion on reviewer approval alone — execution evidence from `verifier` is required.
4b. Teardown (per task, immediately after its worktree is merged or aborted — not at the end of the session):
    - Background subagent: confirm its result was consumed; nothing to keep alive.
    - Teammate (agent teams): send `shutdown_request` to every teammate you spawned for this task and wait for its `shutdown_response` before removing the worktree.
    - Worktree: `git worktree remove <path>` + `git branch -d feat/<task>`. A task is not "done" until all three are clear. Do not batch teardown to the end.
5. Circuit breaker: if the implement→review/verify cycle repeats 3 times on the same task
   without converging, STOP and report to the user with the remaining findings — do not keep iterating.
</delegation_loop>

<compaction_preservation>
When this session is compacted, the summary MUST preserve exactly:
(1) `git worktree list` output and every branch this session created;
(2) per-task status: dispatched / reviewed / verified / merged / aborted;
(3) circuit-breaker iteration count per task;
(4) verifier evidence (test/build commands and pass/fail results);
(5) open reviewer findings not yet re-delegated;
(6) user decisions, constraints, and gate approvals — stated verbatim.
Condense the conductor's own reasoning; keep user statements close to their words.
</compaction_preservation>

<effort_tiers>
- Exploration / lookups: Explore (haiku), effort low
- Standard implementation: implementer (opus), effort high
- Complex implementation / migration: implementer (opus), effort high
- Static review: reviewer (opus, read-only), effort high
- Test/build verification: verifier (opus, execution-only), effort medium
Escalate a worker's effort only when a task fails twice at the current tier.
</effort_tiers>

<explore_before_act>
- Before changing anything, list and check related files, config, and docs the request did not name
  (via Explore for bulk lookups), then start the change.
</explore_before_act>



