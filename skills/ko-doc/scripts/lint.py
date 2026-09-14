#!/usr/bin/env python3
"""ko-doc 린트: 한국어 전달 문서에서 메모체 흔적을 기계적으로 잡는다.

사용: python3 lint.py <markdown 파일> [--strict]

잡는 것 (본문 문장 영역만; 코드 블록·표·제목·인용은 영역별로 따로 검사):
  - 체언 종결: 서술어 없이 명사/명사구로 끝나는 문장
  - 화살표(→), 대시(—, –, ' -- '), 가운뎃점(·) 나열, 물결(~) 축약
  - 괄호 안 문장 (괄호 안에 서술어 종결이 있거나 20자 이상)
  - 번호 제목, 대시 부제, 제목 안 굵게
  - 섹션 사이 수평선
  - 표 셀 안 굵게·화살표·대시
  - 자주 쓰는 AI 단어

린트는 규칙의 절반만 본다. 허수아비 대조, 한 줄 마무리, 무게 잡기, 부사 중첩은 사람이 읽어야 잡힌다.
"""
import re
import sys

ENDINGS = re.compile(
    r"(다|요|까|죠|네|오|음|함|됨|임|ㅁ)[.!?)\"'」』”’]*$"
)
# 체언 종결 판정: 문장이 위 종결어미로 끝나지 않으면 의심. 단 '음/함/됨/임'은 명사형 어미라 본문에서는 여전히 경고.
NOMINAL_ENDINGS = re.compile(r"(음|함|됨|임)[.!?)\"'」』”’]*$")
AI_WORDS = ["핵심", "정확한", "실체", "일체", "전반", "확정", "사실상", "결국", "그대로", "특히"]
ARROWS = re.compile(r"→|⇒|->")
DASHES = re.compile(r"—|–| -- ")
PAREN = re.compile(r"[(（]([^()（）]*)[)）]")


def split_sentences(text):
    parts = re.split(r"(?<=[.!?。])\s+", text.strip())
    return [p for p in parts if p]


def lint(path, strict=False):
    lines = open(path, encoding="utf8").read().split("\n")
    out = []
    in_code = False
    for i, raw in enumerate(lines, 1):
        line = raw.rstrip()
        if line.startswith("```"):
            in_code = not in_code
            continue
        if in_code or not line.strip():
            continue
        # 수평선
        if re.fullmatch(r"\s*-{3,}\s*|\s*\*{3,}\s*", line):
            out.append((i, "수평선", "섹션 구분에 수평선을 쓰지 않는다"))
            continue
        # 제목
        if line.lstrip().startswith("#"):
            title = line.lstrip("#").strip()
            if re.match(r"\d+([.\-]\d+)*[.)]?\s", title):
                out.append((i, "번호 제목", title))
            if DASHES.search(title):
                out.append((i, "제목 대시", title))
            if "**" in title:
                out.append((i, "제목 굵게", title))
            if ENDINGS.search(title) and not NOMINAL_ENDINGS.search(title):
                out.append((i, "문장형 제목", title + " (명사구로)"))
            continue
        # 표 행
        if line.lstrip().startswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if all(re.fullmatch(r":?-+:?", c) for c in cells if c):
                continue
            for c in cells:
                if "**" in c:
                    out.append((i, "표 셀 굵게", c[:60]))
                if ARROWS.search(c):
                    out.append((i, "표 셀 화살표", c[:60] + " (괄호로 부연)"))
                if DASHES.search(c):
                    out.append((i, "표 셀 대시", c[:60] + " (괄호로 부연)"))
            continue
        # 본문 (불릿·인용 포함)
        body = re.sub(r"^\s*([-*+]|\d+[.)]|>|- \[[ x]\])\s*", "", line)
        body_nocode = re.sub(r"`[^`]*`", "`code`", body)
        if ARROWS.search(body_nocode):
            out.append((i, "화살표", body[:70]))
        if DASHES.search(body_nocode):
            out.append((i, "대시", body[:70]))
        if body_nocode.count("·") >= 2:
            out.append((i, "가운뎃점 나열", body[:70]))
        if re.search(r"\d\s*~\s*\d", body_nocode):
            out.append((i, "물결 축약", body[:70]))
        for m in PAREN.finditer(body_nocode):
            inner = m.group(1)
            if len(inner) >= 20 or ENDINGS.search(inner.strip()) and len(inner) > 8:
                out.append((i, "괄호 안 문장", "(" + inner[:50] + ")"))
        for s in split_sentences(body_nocode):
            s2 = s.strip().strip("*").strip()
            # 문장 끝의 짧은 괄호 인용("(§20)." 같은 근거 표기)은 종결 판정에서 뺀다
            s2 = re.sub(r"\s*[(（][^()（）]{0,30}[)）][.!?]?$", "", s2).strip()
            if s2.endswith(":") or s2.endswith("："):
                continue
            if len(s2) < 4:
                continue
            if not ENDINGS.search(s2):
                out.append((i, "체언 종결", s2[-40:]))
            elif NOMINAL_ENDINGS.search(s2):
                out.append((i, "명사형 종결", s2[-40:]))
        if strict:
            for w in AI_WORDS:
                if w in body_nocode:
                    out.append((i, "AI 단어", f"'{w}' in: " + body[:50]))
    return out


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    strict = "--strict" in sys.argv
    if not args:
        print(__doc__)
        sys.exit(2)
    findings = lint(args[0], strict)
    for ln, kind, txt in findings:
        print(f"{ln}: [{kind}] {txt}")
    print(f"\n{len(findings)}건")
    sys.exit(1 if findings else 0)
