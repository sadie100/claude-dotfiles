#!/usr/bin/env python3
"""
Extract user-only messages from Claude Code session .jsonl files for a project.

Why user-only: a typical session is mostly tool calls and assistant output. The
*decisions* and *assumptions* a developer wants to recover live in their own
words — short prompts, corrections, "let's do X instead of Y". Filtering to
user messages typically cuts size by 20-30x and dramatically improves the
signal-to-noise ratio for downstream judgment.

Usage:
    python extract_user_messages.py [--project-dir DIR] [--output-dir DIR]

Defaults:
    --project-dir : current working directory
    --output-dir  : a fresh dir under the system tmp folder; printed at the end
"""

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path


def encode_project_dir(project_dir: Path) -> str:
    """Match Claude Code's project-dir encoding: any of [:\\/] becomes '-'."""
    s = str(project_dir.resolve())
    return re.sub(r"[:\\/]", "-", s)


def find_sessions_dir(project_dir: Path) -> Path:
    home = Path(os.path.expanduser("~"))
    encoded = encode_project_dir(project_dir)
    candidate = home / ".claude" / "projects" / encoded
    if not candidate.is_dir():
        raise SystemExit(
            f"No session dir found for project.\n  Tried: {candidate}\n"
            f"  (Encoded from: {project_dir.resolve()})"
        )
    return candidate


def extract_text_from_content(content) -> list[str]:
    """A user message's content is either a string or a list of content parts."""
    out = []
    if isinstance(content, str):
        out.append(content)
    elif isinstance(content, list):
        for part in content:
            if isinstance(part, dict) and part.get("type") == "text":
                t = part.get("text")
                if t:
                    out.append(t)
    return out


def is_noise(text: str) -> bool:
    """Drop system-reminder wrappers, tool-result echoes, interruption stubs.

    These are technically 'user' messages in the transcript (the harness
    injects them) but carry no developer intent.
    """
    stripped = text.strip()
    if not stripped:
        return True
    if stripped.startswith("<system-reminder"):
        return True
    if stripped.startswith("<command-"):
        return True
    if stripped.startswith("Caveat:"):
        return True
    if stripped.startswith("[Request interrupted"):
        return True
    if stripped.startswith("Called the") and "tool with" in stripped[:60]:
        return True
    if stripped.startswith("Result of calling"):
        return True
    return False


def extract_session(jsonl_path: Path) -> list[str]:
    msgs = []
    try:
        with jsonl_path.open("r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if obj.get("type") != "user":
                    continue
                msg = obj.get("message") or {}
                for text in extract_text_from_content(msg.get("content")):
                    if not is_noise(text):
                        msgs.append(text.strip())
    except OSError as e:
        print(f"warn: {jsonl_path.name}: {e}", file=sys.stderr)
    return msgs


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--project-dir", default=os.getcwd())
    ap.add_argument("--output-dir", default=None)
    args = ap.parse_args()

    project_dir = Path(args.project_dir)
    sessions_dir = find_sessions_dir(project_dir)

    if args.output_dir:
        out_dir = Path(args.output_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
    else:
        out_dir = Path(tempfile.mkdtemp(prefix="session-decisions-"))

    jsonl_files = sorted(sessions_dir.glob("*.jsonl"), key=lambda p: p.stat().st_mtime)
    if not jsonl_files:
        raise SystemExit(f"No .jsonl sessions found in {sessions_dir}")

    summary = []
    for jsonl in jsonl_files:
        msgs = extract_session(jsonl)
        if not msgs:
            continue
        out_path = out_dir / f"{jsonl.stem}.txt"
        body = "\n---\n".join(msgs)
        out_path.write_text(body, encoding="utf-8")
        summary.append((jsonl.stem, len(msgs), out_path.stat().st_size))

    summary.sort(key=lambda x: x[2], reverse=True)

    print(f"sessions dir : {sessions_dir}")
    print(f"output dir   : {out_dir}")
    print(f"session count: {len(summary)}")
    total_bytes = sum(s[2] for s in summary)
    print(f"total size   : {total_bytes} bytes")
    print()
    print("top sessions (by size):")
    for sid, n, sz in summary[:10]:
        print(f"  {sz:>8}  {n:>4} msgs  {sid}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
