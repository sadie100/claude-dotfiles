---
name: mine-session-decisions
description: Mine past Claude Code sessions in this project to surface design decisions, requirement interpretations, and assumptions that should be captured in project docs (README, ADR, retrospective). Extracts user-only messages from session .jsonl files, anchors them to git commits, and produces a categorized candidate list with quotes — the user picks which ones become docs. Use whenever the user asks to recover or extract decisions/assumptions from past sessions ("세션에서 결정 뽑아줘", "이전 대화에서 의사결정 정리해줘", "/mine-session-decisions"). Also offer this skill proactively when the user is filling a "Design Decisions" / "요구사항 해석" / "가정" / "Why we chose" / ADR-style section of a doc and would benefit from past-session context.
---

# Mine Session Decisions

The valuable content for "Design Decisions" / "Assumptions" sections often lives in past conversations — the moments where the developer said "let's do X instead of Y", "I'm assuming the spec means Z", "we decided to skip this". This skill recovers those moments from Claude Code session logs and presents them as a vetted candidate list.

## Why this is non-trivial

Three things make naive approaches fail:

1. **Volume.** A project with weeks of sessions can have 10MB+ of .jsonl. Most of it is tool calls and assistant output, neither of which contains developer intent. The trick is to extract only `type: "user"` messages — typically a 20-30x size reduction with much better signal.
2. **Anchoring.** Decisions are easier to recognize when paired with what they produced. Git log gives commits to anchor candidates to.
3. **Judgment.** Distinguishing "real decision worth recording" from "minor tactical request" is a judgment call. Keyword grep does poorly. A subagent reading the curated text does well.

Keep these in mind when adapting the workflow — for example, don't fall back to grepping raw .jsonl if the extraction script fails.

## Workflow

### 1. Confirm scope with the user

Before extracting, briefly confirm:
- **Target doc/section** — what are they trying to fill? README "Design Decisions"? An ADR? A retrospective? Knowing this lets you tailor the extraction criteria and the final format. If they invoked the skill proactively, this may already be clear from context.
- **Already-covered ground** — if the doc has existing entries, list them so the extraction step doesn't surface duplicates.

Keep this short — one or two lines, not a formal interview.

### 2. Extract user messages

Run the bundled script from the project's working directory:

```bash
python <skill-path>/scripts/extract_user_messages.py
```

This finds the session dir for the current project (under `~/.claude/projects/<encoded-cwd>/`), filters each `.jsonl` down to user-authored text, strips system-reminder noise, and writes one `.txt` per session to a fresh tmp directory. It prints the output path, total size, and the top sessions by size.

Optional flags:
- `--project-dir DIR` — point at a different repo (defaults to cwd)
- `--output-dir DIR` — pin the output location

If the extracted total is over ~1MB, mention it to the user — they may want to scope down (e.g., last N sessions only) before sending it to a subagent.

### 3. Get commit anchors

```bash
git log --oneline -50
```

50 is a starting point; bump up for older projects, down for tiny ones. The goal is enough commits to map each candidate decision to "what shipped from it".

### 4. Dispatch a subagent to extract candidates

Spawn a general-purpose subagent and give it:
- The path to the extracted `.txt` directory
- The git log
- The target doc/section context from step 1
- Any existing entries to avoid duplicating
- The extraction criteria below

**Extraction criteria — include:**
- Explicit "X instead of Y" decisions with reasoning
- Assumptions about ambiguous specs ("I'll interpret this as...", "the spec doesn't say so I'm going with...")
- Trade-offs the user weighed and resolved
- Things intentionally *not* done, and why
- Decisions about UX, state shape, URL structure, error handling that drove implementation

**Exclude:**
- Pure debugging back-and-forth
- One-off tactical requests the user delegated without judgment
- Anything derivable from reading the code as it stands now
- Items the target doc already covers

**Output format** (subagent should produce this exact shape):

```markdown
### [Category 1 — e.g., 요구사항 해석 및 가정]

1. **[Short title]** (session: <id-prefix>, commit: <hash>)
   - Quoted user statement (verbatim, 1-3 sentences, original language)
   - One-line justification for why this belongs in the doc

2. ...

### [Category 2 — e.g., 설계 결정과 이유]
...
```

Ask the subagent for ~5-10 candidates per category and to drop weak ones rather than pad. Quotes should be the user's actual words, not paraphrases — quotes are the raw material the user will judge from.

### 5. Present to the user for selection

Surface the candidate list as-is (don't pre-filter beyond what the subagent did). Let the user pick, drop, merge, or ask for more context on specific candidates before any doc gets edited.

Stop here unless the user explicitly asks for the next step (drafting doc text). This skill's scope ends at the curated candidate list — what to do with it is the user's call.

## When the standard workflow needs to bend

- **Tiny project, few sessions** — skip the subagent and just read the extracted text yourself.
- **Sessions don't exist** (script reports "No session dir found") — surface this immediately. There's nothing to mine. Suggest the user manually narrate decisions instead.
- **Output dir is huge (>2MB after extraction)** — narrow the scope before subagent dispatch: ask the user which date range / feature area matters, then pass only matching files.
- **The doc has a unique tone** — read 1-2 existing entries before step 4 so the subagent's output style matches what the user will paste into.
