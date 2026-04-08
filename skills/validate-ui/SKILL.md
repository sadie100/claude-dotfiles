---
name: validate-ui
description: Validate UI changes in the browser using Chrome DevTools MCP. Use when the user asks to verify, check, or validate UI changes in the browser, or mentions browser testing, visual verification, or E2E-style validation after code edits.
---

# UI Validation with Chrome DevTools

MCP 서버 `user-chrome-devtools`를 사용하여 코드 변경 후 브라우저에서 UI를 검증한다.

## Prerequisites

- 개발 서버가 `http://localhost:3005`에서 실행 중이어야 한다
- Chrome 브라우저가 열려 있고, 대상 페이지가 로드되어 있어야 한다

## Two Modes

### Mode 1 - Auto (default)

사용자가 기대 동작을 제공하지 않은 경우. 코드 변경 기반 회귀 검출 + 변경 적용 확인.

> "이 컴포넌트 수정하고 브라우저에서 확인해줘"

### Mode 2 - Scenario-based

사용자가 인터랙션 시나리오와 기대 결과를 함께 제공한 경우. 시나리오를 실제 수행하고 기대 결과와 대조.

> "수정하고 확인해줘. 목록에서 첫 항목 클릭하면 상세 모달이 열려야 해"

---

## Workflow

### Phase 1 - Target Setup

대상 브라우저 탭을 선택하고 측정 도구를 리셋한다.

```
1. CallMcpTool: server="user-chrome-devtools", toolName="list_pages"
   → 열린 탭 목록에서 localhost:3005 페이지의 pageId를 찾는다

2. CallMcpTool: server="user-chrome-devtools", toolName="select_page"
   arguments: { "pageId": <found_id> }

3. CallMcpTool: server="user-chrome-devtools", toolName="evaluate_script"
   arguments: { "function": "() => { console.clear(); return 'console cleared'; }" }
```

수정한 파일이 어떤 URL에 대응하는지 모를 경우, `src/App.tsx`와 `src/pages/story/routes.tsx`를 읽어서 라우트 매핑을 파악한다.

### Phase 2 - BEFORE Baseline

코드 수정 전 현재 상태를 4계층으로 수집한다.

```
Layer 1 - A11y Snapshot:
  CallMcpTool: server="user-chrome-devtools", toolName="take_snapshot"
  arguments: { "verbose": true }
  → 요소 존재 여부, 텍스트 내용, 상태 (checked, disabled 등)

Layer 2 - Screenshot:
  CallMcpTool: server="user-chrome-devtools", toolName="take_screenshot"
  → 시각적 렌더링 상태 (레이아웃, 색상 등 a11y로 못 보는 부분)

Layer 3 - DOM Query (필요 시):
  CallMcpTool: server="user-chrome-devtools", toolName="evaluate_script"
  arguments: { "function": "() => { return document.querySelector('.target').innerText; }" }
  → 특정 DOM 속성, CSS 값 등 정밀 확인

Layer 4 - Runtime Logs:
  CallMcpTool: server="user-chrome-devtools", toolName="list_console_messages"
  arguments: { "types": ["error", "warn"] }

  CallMcpTool: server="user-chrome-devtools", toolName="list_network_requests"
  arguments: { "resourceTypes": ["fetch", "xhr"] }
```

모든 계층을 매번 수집할 필요는 없다. 상황에 따라 판단:
- 단순 텍스트 변경 → Layer 1 + Layer 4면 충분
- 레이아웃/스타일 변경 → Layer 2 추가
- 특정 DOM 상태 확인 필요 → Layer 3 추가

### Phase 3 - Apply Change + Wait for HMR

1. 코드 수정을 적용한다
2. Vite HMR이 반영될 때까지 대기한다

```
CallMcpTool: server="user-chrome-devtools", toolName="wait_for"
arguments: { "time": 2000 }
```

HMR이 적용되지 않는 경우 (라우트 변경, 전역 설정 변경 등):
```
CallMcpTool: server="user-chrome-devtools", toolName="navigate_page"
arguments: { "type": "reload", "ignoreCache": true }

CallMcpTool: server="user-chrome-devtools", toolName="wait_for"
arguments: { "time": 3000 }
```

### Phase 4 - AFTER Collection + Validation

#### Mode 1 (Auto)

Phase 2와 동일한 계층으로 AFTER 상태를 수집하고 BEFORE와 비교한다.

**판정 기준:**
- 새로운 console error/warn이 발생했는가
- 네트워크 요청 중 4xx/5xx 응답이 있는가
- a11y 스냅샷에서 예기치 않은 요소 소실이 있는가
- 코드 변경 의도가 스냅샷에 반영되었는가 (예: 텍스트 변경이면 해당 텍스트가 보이는지)
- 스크린샷에서 명백한 렌더링 이상이 있는가 (흰 화면, 깨진 레이아웃 등)

#### Mode 2 (Scenario-based)

사용자가 제공한 시나리오를 단계별로 실행한다. 각 단계 후 검증을 수행한다.

```
시나리오 예: "새 문의 버튼 클릭 → 모달 열림 → 제목 입력 → 등록"

Step 1: take_snapshot → '새 문의' 버튼의 uid 확인
Step 2: click(uid) → 클릭
Step 3: wait_for(1000) → 모달 렌더링 대기
Step 4: take_snapshot → 모달이 열렸는지 확인
Step 5: fill(uid, "테스트 제목") → 제목 입력
Step 6: click(등록 버튼 uid) → 등록
Step 7: wait_for(2000) → API 응답 대기
Step 8: take_snapshot → 결과 확인
Step 9: list_console_messages → 에러 확인
Step 10: list_network_requests → API 성공 확인
```

인터랙션에 사용하는 주요 도구:
- `click`: arguments `{ "uid": "<snapshot의 uid>", "includeSnapshot": true }`
- `fill`: arguments `{ "uid": "<uid>", "value": "입력값" }`
- `type_text`: arguments `{ "text": "입력값", "uid": "<uid>" }`
- `hover`: arguments `{ "uid": "<uid>" }`
- `wait_for`: arguments `{ "time": <ms> }` 또는 `{ "selector": "<css>" }`

### Phase 5 - Judgment Loop

```
FAIL 조건 (하나라도 해당하면):
  - list_console_messages에 새로운 error 존재
  - list_network_requests에 4xx/5xx 응답 존재
  - a11y 스냅샷에서 기대 요소가 없음
  - (Mode 2) 시나리오 기대 결과 미충족

→ 코드 수정 → Phase 3부터 재실행 (최대 3회 반복)

PASS 조건:
  - 위 FAIL 조건에 해당 없음
  - (Mode 1) 코드 변경 의도가 반영됨
  - (Mode 2) 모든 시나리오 단계 통과

→ 결과 보고 후 종료
```

---

## Tool Reference (server: user-chrome-devtools)

| Tool | Purpose | Key Arguments |
|------|---------|---------------|
| `list_pages` | 열린 탭 목록 | (none) |
| `select_page` | 타겟 탭 선택 | `pageId` (required) |
| `take_snapshot` | a11y 트리 스냅샷 | `verbose`: bool |
| `take_screenshot` | 시각 캡처 | `format`, `fullPage`, `uid` |
| `evaluate_script` | JS 실행 | `function` (required), `args` |
| `list_console_messages` | 콘솔 메시지 | `types`: ["error","warn",...] |
| `list_network_requests` | 네트워크 요청 | `resourceTypes`: ["fetch","xhr",...] |
| `navigate_page` | 페이지 이동 | `type`: "url"\|"reload", `url` |
| `click` | 요소 클릭 | `uid` (required), `includeSnapshot` |
| `fill` | 입력 필드 채우기 | `uid`, `value` |
| `type_text` | 텍스트 입력 | `uid`, `text` |
| `hover` | 호버 | `uid` (required) |
| `wait_for` | 대기 | `time` (ms) 또는 `selector` (CSS) |

## Reporting

검증 완료 후 결과를 다음 형식으로 보고한다:

```
## UI 검증 결과: PASS / FAIL

- 검증 URL: http://localhost:3005/...
- 검증 모드: Auto / Scenario-based
- 콘솔 에러: 없음 / [에러 내용]
- 네트워크 실패: 없음 / [실패 요청]
- 스냅샷 변경: [요약]
- (Mode 2) 시나리오 결과: [각 단계 통과 여부]
- 반복 횟수: N회
```
