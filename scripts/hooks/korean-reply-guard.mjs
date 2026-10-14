#!/usr/bin/env node
/*
  Stop 훅 — 마지막 답변이 영어 위주면 한국어로 다시 쓰게 막는다.
  사용자는 모든 답변을 한국어로 받기를 원한다(2026-10-14, 메모리 규칙만으로는 영어 보고가 반복돼 훅으로 강제).
  판정: 마지막 도구 결과 이후의 assistant 텍스트에서 코드블록·인라인코드·URL·경로를 지운 뒤
  한글 글자 수와 라틴 글자 수를 센다. 라틴이 MIN_LATIN 이상이고 한글 비율이 MIN_RATIO 미만이면 block.
  stop_hook_active(이미 한 번 막혀 다시 쓴 응답)면 무한 루프를 피하려고 통과시킨다.
  어떤 오류든 통과(fail-open) — 이 훅이 세션을 멈추게 해서는 안 된다.
*/
import fs from "node:fs";

const MIN_LATIN = 150;
const MIN_RATIO = 0.25;

function readStdin() {
    try {
        return fs.readFileSync(0, "utf8");
    } catch {
        return "";
    }
}

function lastReplyText(transcriptPath) {
    const lines = fs.readFileSync(transcriptPath, "utf8").split("\n").filter(Boolean);
    const parts = [];
    for (let i = lines.length - 1; i >= 0; i--) {
        let e;
        try {
            e = JSON.parse(lines[i]);
        } catch {
            continue;
        }
        const content = e && e.message && e.message.content;
        if (e.type === "user") {
            // 도구 결과나 사용자 입력을 만나면 그 뒤가 "마지막 답변"이다
            if (parts.length) break;
            continue;
        }
        if (e.type !== "assistant" || !Array.isArray(content)) continue;
        if (content.some((b) => b && b.type === "tool_use") && parts.length) break;
        for (let j = content.length - 1; j >= 0; j--) {
            const b = content[j];
            if (b && b.type === "text" && b.text) parts.unshift(b.text);
        }
    }
    return parts.join("\n");
}

function strip(text) {
    return text
        .replace(/```[\s\S]*?```/g, " ")
        .replace(/`[^`\n]*`/g, " ")
        .replace(/\]\([^)]*\)/g, "]")
        .replace(/https?:\/\/\S+/g, " ")
        .replace(/[\w.-]*\/[\w./-]+/g, " ");
}

try {
    const input = JSON.parse(readStdin() || "{}");
    if (input.stop_hook_active) process.exit(0);
    if (!input.transcript_path) process.exit(0);
    const text = strip(lastReplyText(input.transcript_path));
    const hangul = (text.match(/[가-힣]/g) || []).length;
    const latin = (text.match(/[A-Za-z]/g) || []).length;
    if (latin < MIN_LATIN) process.exit(0);
    const ratio = hangul / (hangul + latin);
    if (ratio >= MIN_RATIO) process.exit(0);
    process.stdout.write(
        JSON.stringify({
            decision: "block",
            reason:
                "방금 답변이 영어로 작성됐습니다(한글 비율 " +
                Math.round(ratio * 100) +
                "%). 사용자는 모든 답변을 한국어로 받기를 원합니다. 같은 내용을 한국어로 다시 작성해 답변하세요. 코드 식별자·명령어·파일 경로만 원문을 유지합니다.",
        })
    );
} catch {
    process.exit(0);
}
