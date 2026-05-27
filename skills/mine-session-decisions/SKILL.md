---
name: mine-session-decisions
description: Mine past Claude Code sessions in this project to recover design decisions, requirement interpretations, and assumptions, then write them into the target doc (README, ADR, retrospective). Extracts user-only messages from session .jsonl files, anchors them to git commits, presents a categorized candidate list for the user to pick from, and writes the selected items into the doc in the doc's existing tone. Use whenever the user asks to recover or document decisions/assumptions from past sessions ("세션에서 결정 뽑아줘", "이전 대화에서 의사결정 정리해서 README에 넣어줘", "/mine-session-decisions"). Also offer this skill proactively when the user is filling a "Design Decisions" / "요구사항 해석" / "가정" / "Why we chose" / ADR-style section of a doc and would benefit from past-session context.
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

### 1. Confirm target and scope with the user

Before extracting, nail down two things:

- **Target output location** — *where* should the result land? Use `AskUserQuestion` if it isn't already obvious from the request. Three common shapes:
  - **Existing file + section** — e.g. "README.md의 '설계 결정과 이유' 섹션 뒤에", "docs/adr/0007-foo.md의 Decision 절"
  - **New file** — e.g. "docs/decisions.md 새로 만들어서"
  - **A scratch folder** — e.g. "/tmp/extracted-decisions.md, 보고 직접 옮길게"

  If the user is ambiguous, infer from context (an open IDE file with an empty "Design Decisions" section is a strong signal) and confirm in one line before proceeding rather than asking a long-form question. Whatever the target is, remember it — step 6 will write there.

- **Already-covered ground** — if the target file has existing entries in the relevant section, list them briefly so step 4 doesn't surface duplicates.

Keep this short — one or two lines plus an `AskUserQuestion` if needed, not a formal interview.

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

Surface the candidate list as-is (don't pre-filter beyond what the subagent did). Let the user pick, drop, merge, or ask for more context on specific candidates before anything gets written.

If the doc has obviously dependent decisions (e.g., the user added a candidate that needs a new doc section to live in), surface that branch one question at a time rather than guessing.

### 6. Write the selected candidates to the target

Write to the location captured in step 1 — an existing doc section, a new file, or a scratch markdown file. The writing principles below apply in all three cases; only the destination differs.

If the target is an **existing doc with prior entries**, **read 1-2 of those entries** first to lock in tone. The new content lives alongside whatever's already there, so it needs to blend — a section that suddenly switches voice, length, or formatting reads like it was bolted on.

If the target is a **new file or scratch markdown**, there's nothing to mirror, so pick a tone deliberately. A safe default: `###` headers per item, one direct opening sentence stating the decision, bullets for rationale, trade-off in the final line. Write one sample item first and let the user redirect before doing the rest.

Tone things to mirror:
- Heading depth (e.g., `###` vs `####`)
- Opening sentence shape — direct statement of the decision, or a question, or a context paragraph first?
- Bullet style — bare bullets, bold lead-ins, or prose paragraphs?
- Whether trade-offs sit in their own paragraph at the end or are inlined
- Length per entry — match the existing entries' depth roughly, don't write twice as long

**Important: write as prose, not as quoted dialogue.** The quotes captured in step 4 are *raw material* for your understanding, not the final form. A README entry should sound like "we chose X because Y", not like "the developer said 'let's do X'". The reader doesn't care that it came from a chat.

After writing, briefly note which sections were touched and offer to trim or re-balance if the new content unbalances the doc.

## When the standard workflow needs to bend

- **Tiny project, few sessions** — skip the subagent and just read the extracted text yourself.
- **Sessions don't exist** (script reports "No session dir found") — surface this immediately. There's nothing to mine. Suggest the user manually narrate decisions instead.
- **Output dir is huge (>2MB after extraction)** — narrow the scope before subagent dispatch: ask the user which date range / feature area matters, then pass only matching files.
- **The doc has no existing entries to mirror tone from** — propose a tone (compact direct-statement bullets is a safe default) and write one entry as a sample before doing the rest, so the user can redirect early.
- **The user explicitly asks to stop at the candidate list** — honor that and skip step 6. Save the candidate list as a standalone markdown file the user can act on later.
