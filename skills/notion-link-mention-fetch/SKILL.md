---
name: notion-link-mention-fetch
description: Notion MCP fetch가 멘션 형식으로 붙여넣은 외부 링크(피그마 등)를 빈 텍스트로 떨궈서 링크가 안 보일 때, ntn CLI raw API로 link_preview 멘션 URL을 추출한다. Use when syncing a Notion page and pasted-as-mention links (Figma, 외부 URL 멘션) are missing/empty in the MCP fetch output — triggers like "노션에 붙인 피그마 링크가 안 와", "멘션 링크 추출", "노션 동기화했는데 링크가 비어있어".
---

# Notion 멘션 링크(link_preview) 추출

## 문제

Notion에서 외부 URL(피그마 등)을 **"멘션으로 붙여넣기(Paste as mention)"** 하면 내부적으로 rich text의 `mention` 타입 중 `link_preview`가 된다. Notion MCP의 `notion-fetch`(enhanced markdown 변환)는 이 타입을 렌더하지 않고 **아무 텍스트도 없이 떨궈버린다** — 페이지를 fetch하면 그 자리가 빈 채로 온다. 문서 동기화 시 링크가 소리소문없이 유실되므로, fetch 결과에서 "디자인 :" 같은 라벨 뒤가 이유 없이 비어 있으면 이 케이스를 의심할 것.

## 해결: ntn CLI로 raw API 호출

전제: `ntn`이 설치·로그인돼 있어야 함 (`which ntn`, 안 되어 있으면 /setup-notion-cli 참조).

1. **페이지의 블록 목록 조회** — 페이지 ID는 노션 URL 끝 32자리 hex. UUID 하이픈 형식(`8-4-4-4-12`)으로 바꿔야 한다 (하이픈 없으면 400 invalid_request_url).

   ```bash
   ntn api "/v1/blocks/{page-uuid}/children" </dev/null
   ```

   `</dev/null` 필수 — 없으면 ntn이 stdin 입력을 기다리며 행에 걸릴 수 있다. 추가 인자(`page_size==100` 등)도 행 유발 사례가 있으니 붙이지 말 것 (기본 100개면 대부분 충분).

2. **대상 블록의 children 조회** — 링크가 표 안에 있으면 1번 결과에서 `table` 블록 ID를 찾아 같은 방식으로 children(= table_row들)을 조회한다.

3. **link_preview 멘션 파싱** — rich text 배열에서 `type == "mention"` && `mention.type == "link_preview"`인 항목의 `mention.link_preview.url`이 원본 URL이다.

   ```python
   for rt in cell:  # rich text array (table_row.cells[i] 또는 paragraph.rich_text 등)
       if rt["type"] == "mention" and rt["mention"].get("type") == "link_preview":
           url = rt["mention"]["link_preview"]["url"]
   ```

4. 추출한 URL을 동기화 대상 문서에 일반 마크다운 링크로 넣는다.

## 참고

- 사용자가 노션에 "URL로 붙여넣기(일반 링크)"로 붙이면 MCP fetch에도 그대로 내려오므로 이 스킬이 필요 없다. 단 이미 멘션으로 붙어 있는 문서를 고치라고 요구하지 말고 이 방법으로 추출할 것.
- 페이지/DB 멘션(`mention.type == "page"` 등)은 MCP fetch가 `<mention-page>`로 정상 렌더한다. 문제는 외부 URL 멘션(`link_preview`)뿐.
