---
name: measure-rerender
description: Measure React component re-rendering performance in the browser using Chrome DevTools MCP. Use when the user reports unnecessary re-renders, asks to profile rendering performance, measure component render counts, or optimize React rendering after state changes.
---

# React 리렌더링 성능 측정

MCP 서버 `user-chrome-devtools`를 사용하여 상태 변경 시 React 컴포넌트의 리렌더링 성능을 측정한다.

## Prerequisites

- 개발 서버가 `http://localhost:3005`에서 실행 중이어야 한다
- Chrome 브라우저가 열려 있고, 대상 페이지가 로드되어 있어야 한다
- React DevTools 확장 설치 권장 (Layer 1 정밀 측정용)
- **반드시 `user-chrome-devtools` MCP 서버만 사용한다. `cursor-ide-browser`(인앱 브라우저)는 사용하지 않는다.** 이 스킬의 모든 브라우저 조작은 외부 Chrome 브라우저에서 수행해야 한다.

## Two Modes

### Mode 1 - Snapshot (default)

단일 인터랙션의 리렌더링 영향을 측정한다.

> "이 페이지에서 필터 변경할 때 리렌더링 측정해줘"

### Mode 2 - Comparison

코드 변경 전후 리렌더링 차이를 비교한다.

> "memo 적용 전후로 리렌더링 횟수 비교해줘"

---

## Workflow

### Phase 1 - Target Setup

대상 브라우저 탭을 선택하고 페이지를 준비한다.

```
1. CallMcpTool: server="user-chrome-devtools", toolName="list_pages"
   → localhost:3005 페이지의 pageId를 찾는다

2. CallMcpTool: server="user-chrome-devtools", toolName="select_page"
   arguments: { "pageId": <found_id> }
```

수정한 파일이 어떤 URL에 대응하는지 모를 경우, `src/App.tsx`와 `src/pages/story/routes.tsx`를 읽어서 라우트 매핑을 파악한다.

### Phase 2 - Instrument

렌더 추적기를 주입하고 성능 트레이스를 시작한다.

**Step 1 - 렌더 추적기 주입:**

[scripts.md](scripts.md)의 `inject-tracker` 스크립트를 `evaluate_script`로 주입한다.

```
CallMcpTool: server="user-chrome-devtools", toolName="evaluate_script"
arguments: { "function": "<inject-tracker 스크립트>" }
```

반환값의 `hasDevTools`로 Layer 1(Fiber 추적) 사용 가능 여부를 확인한다.
- `true` → 컴포넌트 단위 렌더 카운트 가능
- `false` → DOM MutationObserver 폴백 (영역 단위 추정)

**Step 2 - Performance Trace 시작:**

```
CallMcpTool: server="user-chrome-devtools", toolName="performance_start_trace"
arguments: { "reload": false, "autoStop": false }
```

페이지 로드 성능도 함께 측정하려면 `reload: true`로 설정한다.

### Phase 3 - Execute Interaction

사용자가 지정한 인터랙션을 수행한다.

```
1. CallMcpTool: server="user-chrome-devtools", toolName="take_snapshot"
   arguments: { "verbose": true }
   → 인터랙션 대상 요소의 uid를 찾는다

2. 인터랙션 실행 (click, fill, type_text, hover 등)

3. CallMcpTool: server="user-chrome-devtools", toolName="wait_for"
   arguments: { "time": 1000 }
   → 렌더링 완료 대기
```

동일 인터랙션을 3회 반복하면 데이터 신뢰도가 높아진다. 매 반복 사이에 `reset-tracker` 스크립트를 실행한다.

### Phase 4 - Collect Data & Export

**Step 1 - 렌더 추적 데이터 수집:**

[scripts.md](scripts.md)의 `collect-data` 스크립트를 `evaluate_script`로 실행한다.

```
CallMcpTool: server="user-chrome-devtools", toolName="evaluate_script"
arguments: { "function": "<collect-data 스크립트>" }
```

수집된 JSON 데이터를 파일로 저장한다:

```
Write tool → perf-traces/render-data-{YYYY-MM-DD-HHmmss}.json
```

**Step 2 - Performance Trace 종료 + 파일 저장:**

`filePath`를 지정하여 트레이스 원본을 파일로 내보낸다. 이 파일은 Chrome DevTools Performance 탭에서 "Load profile"로 직접 열어볼 수 있다.

```
CallMcpTool: server="user-chrome-devtools", toolName="performance_stop_trace"
arguments: { "filePath": "perf-traces/trace-{YYYY-MM-DD-HHmmss}.json.gz" }
```

`{YYYY-MM-DD-HHmmss}`는 측정 시점 타임스탬프로 치환한다. `perf-traces/` 디렉토리가 없으면 먼저 생성한다.

### Phase 5 - Analyze

수집된 데이터를 분석한다.

**렌더 추적 데이터 분석:**
- `componentCounts`: 컴포넌트별 렌더 횟수 → 비정상적으로 높은 항목 식별
- `renders` 배열: 시간순 렌더 이벤트 → 연쇄 렌더링 패턴 탐지
- `domMutations`: DOM 변경 위치 → 영향 범위 추정

**불필요 리렌더 판정 기준:**
- 인터랙션과 무관한 컴포넌트가 렌더되었는가 (예: 필터 변경 시 Header가 렌더)
- 동일 컴포넌트가 연속으로 여러 번 렌더되었는가 (배치 누락)
- props/state 변경 없이 렌더되었는가 (참조 동일성 문제)

**Performance Trace 분석 (선택):**

트레이스 결과에서 insight가 있으면 상세 분석한다.

```
CallMcpTool: server="user-chrome-devtools", toolName="performance_analyze_insight"
arguments: { "insightSetId": "<id>", "insightName": "<name>" }
```

### Phase 6 - Report

결과를 아래 형식으로 보고한다.

```
## 리렌더링 측정 결과

- 측정 URL: http://localhost:3005/...
- 수행한 인터랙션: [설명]
- 측정 시간: N ms
- 추적 방식: Layer 1 (Fiber) / Layer 3 (MutationObserver)

### 내보낸 파일
- Performance Trace: `perf-traces/trace-YYYY-MM-DD-HHmmss.json.gz` (Chrome DevTools Performance 탭에서 열기)
- 렌더 추적 데이터: `perf-traces/render-data-YYYY-MM-DD-HHmmss.json`

### 컴포넌트별 렌더 횟수
| 컴포넌트 | 렌더 횟수 | 평균 소요시간 | 판정 |
|----------|-----------|-------------|------|
| Header   | 5         | 2.3ms       | 불필요 |
| Sidebar  | 5         | 4.1ms       | 불필요 |
| Content  | 2         | 1.2ms       | 정상   |

### DOM 변경 요약
- 총 mutation 횟수: N
- 주요 변경 영역: [영역 목록]

### Performance Trace 요약 (수집 시)
- Total Blocking Time: Nms
- CWV 점수: ...

### 최적화 제안
1. [구체적 컴포넌트]에 React.memo 적용 권장 — props 변경 없이 렌더됨
2. [구체적 상태]를 별도 Context/store로 분리 — 무관한 컴포넌트 리렌더 방지
3. useMemo/useCallback으로 참조 안정성 확보 — [구체적 위치]
```

Mode 2 (Comparison)에서는 BEFORE/AFTER 테이블을 나란히 배치한다.

---

## Tool Reference (server: user-chrome-devtools)

| Tool | Purpose | Key Arguments |
|------|---------|---------------|
| `list_pages` | 열린 탭 목록 | (none) |
| `select_page` | 타겟 탭 선택 | `pageId` (required) |
| `evaluate_script` | JS 실행 (추적기 주입/수집) | `function` (required) |
| `performance_start_trace` | 트레이스 시작 | `reload`, `autoStop` (required) |
| `performance_stop_trace` | 트레이스 종료 | `filePath` (optional) |
| `performance_analyze_insight` | 인사이트 상세 | `insightSetId`, `insightName` |
| `take_snapshot` | a11y 트리 스냅샷 | `verbose`: bool |
| `click` | 요소 클릭 | `uid` (required) |
| `fill` | 입력 필드 채우기 | `uid`, `value` |
| `type_text` | 텍스트 입력 | `uid`, `text` |
| `hover` | 호버 | `uid` (required) |
| `wait_for` | 대기 | `time` (ms) 또는 `selector` (CSS) |
