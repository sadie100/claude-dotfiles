# Claude Code Harness 구성 현황

<!-- harness-sync-fingerprint: 53996da2d4a810f237b68a16e00da6bb9980436be1315dfdf5a13bf1e5d0c02b -->

이 레포지토리에 설치된 Claude Code 설정(스킬, 플러그인, 훅, MCP 등)을 정리한 문서입니다.

> 플러그인 / 스킬 / 훅 섹션은 `scripts/harness-sync/harness-sync.mjs`가 자동으로 갱신합니다.
> 마커(`<!-- AUTO:BEGIN ... -->` / `<!-- AUTO:END ... -->`) 사이는 직접 수정하지 마세요.
> 모델·권한 정보는 [`settings.json`](settings.json)에서 직접 확인하세요.

---

## 플러그인 (Enabled Plugins)

<!-- AUTO:BEGIN plugins -->
### Official Plugins (`claude-plugins-official`)

| 플러그인 | 상태 | 설명 |
|----------|------|------|
| `context7` | ✅ 활성 | 라이브러리/프레임워크 최신 문서 조회 |
| `code-simplifier` | ✅ 활성 | 코드 단순화 및 리팩토링 |
| `code-review` | ✅ 활성 | PR 코드 리뷰 |
| `feature-dev` | ✅ 활성 | 코드베이스 분석 기반 기능 개발 가이드 |
| `frontend-design` | ✅ 활성 | 프로덕션급 프론트엔드 UI 생성 |
| `typescript-lsp` | ✅ 활성 | TypeScript 언어 서버 지원 |
| `playwright` | ✅ 활성 | 브라우저 자동화 및 테스트 |
| `chrome-devtools-mcp` | ✅ 활성 | Chrome 브라우저 제어/검사 MCP (공식 마켓플레이스 버전) |
| `superpowers` | ✅ 활성 | 확장 기능 모음 |
| `security-guidance` | ✅ 활성 | 보안 가이드라인 제공 |
| `claude-md-management` | ✅ 활성 | CLAUDE.md 파일 관리/개선 |
| `skill-creator` | ✅ 활성 | 스킬 생성/수정/평가 |
| `atlassian` | ✅ 활성 | Jira/Confluence 연동 |
| `notion` | ✅ 활성 | Notion 연동 |
| `slack` | ✅ 활성 | Slack 연동 |
| `ralph-loop` | ❌ 비활성 | 반복 실행 루프 |

### Anthropic Agent Skills (`anthropic-agent-skills`)

| 플러그인 | 상태 | 설명 |
|----------|------|------|
| `document-skills` | ✅ 활성 | PDF, PPTX, XLSX, 웹 아티팩트 등 문서 관련 스킬 모음 |

### Chrome DevTools (`chrome-devtools-plugins`)

| 플러그인 | 상태 | 설명 |
|----------|------|------|
| `chrome-devtools-mcp` | ✅ 활성 | Chrome DevTools 프로토콜 기반 브라우저 디버깅/자동화 |

### Custom Marketplace (`ui-ux-pro-max-skill`)

| 플러그인 | 상태 | 설명 |
|----------|------|------|
| `ui-ux-pro-max` | ✅ 활성 | AI 기반 디자인 인텔리전스 스킬. 제품 요구사항을 분석하여 디자인 시스템을 자동 생성 |
<!-- AUTO:END plugins -->

---

## 스킬 (Skills)

현재 세션에서 사용 가능한 모든 스킬 목록입니다. **소속** 컬럼은 스킬의 출처를 의미합니다:
- `custom`: 이 레포의 `skills/` 디렉토리에 정의된 로컬 스킬
- `built-in`: Claude Code 내장 스킬 (네임스페이스 없음)
- 그 외: 해당 플러그인/마켓플레이스 이름

<!-- AUTO:BEGIN skills -->
### 기획·설계

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `superpowers:brainstorming` | 기능/컴포넌트 설계 시작 시 | superpowers | 구현 전 사용자 의도/요구사항/설계 탐색 |
| `superpowers:writing-plans` | 멀티스텝 작업 계획 작성 시 | superpowers | 코드 작업 전 구현 계획 작성 |
| `dev-prd` | `/dev-prd {기능명}` | custom | PRD(제품 요구사항 문서) 작성. 사용자와 협업하여 기능 기획 |
| `dev-architecture` | `/dev-architecture {기능명}` | custom | 아키텍처 설계. 기술 옵션 분석 및 트레이드오프 제시 |
| `dev-spec` | `/dev-spec {기능명}` | custom | 상세 구현 스펙 작성. 인수 조건(AC)을 Given-When-Then 형식으로 정의 |
| `dev-testcase` | `/dev-testcase {기능명}` | custom | 테스트 케이스 자동 도출. 스펙의 AC에서 TC를 생성 |
| `to-prd` | 대화 컨텍스트 → PRD 변환 시 | mattpocock/skills | 현재 대화 맥락을 PRD로 정리하여 이슈 트래커에 게시 |
| `grill-me` | 계획/설계 검증 요청 시 | mattpocock/skills | 계획·설계를 결정 트리 단위로 끝까지 질의하며 검증 |
| `grill-with-docs` | 도메인 문서 기반 계획 검증 시 | mattpocock/skills | CONTEXT.md/ADR 기반으로 계획을 검증하고 문서 인라인 갱신 |

### 오케스트레이션·파이프라인

여러 단계/에이전트/스킬을 묶어 한 호출로 자동 실행하는 메타 워크플로우.

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `front-execute` | `/front-execute` (프론트엔드 구현 + 검증 시) | custom | 문서/지시 입력 → 구현 → 타입체크/유닛테스트 → UI 검증 루프(최대 5회 자동 수정) → 최종 코드 리뷰 |
| `dev-process` | `/dev-process {기능명}` | custom | PRD → 아키텍처 → 스펙 → TC 4단계 오케스트레이터 |
| `feature-dev:feature-dev` | 기능 개발 요청 시 | feature-dev | 코드베이스 분석 → 설계 → 가이드형 구현을 묶는 멀티스텝 워크플로우 |
| `superpowers:executing-plans` | 작성된 계획 실행 시 | superpowers | 리뷰 체크포인트 포함 별도 세션에서 계획 실행 |
| `superpowers:subagent-driven-development` | 독립 작업이 있는 계획 실행 시 | superpowers | 현재 세션에서 서브에이전트로 독립 작업 실행 |
| `superpowers:dispatching-parallel-agents` | 독립 작업 2개 이상 시 | superpowers | 공유 상태 없는 독립 작업 병렬 실행 |

### 구현

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `superpowers:test-driven-development` | 기능/버그픽스 구현 시 | superpowers | 구현 코드 작성 전 TDD 적용 |
| `tdd` | TDD 기반 개발 요청 시 | mattpocock/skills | red-green-refactor 루프 기반 테스트 우선 개발 |
| `superpowers:using-git-worktrees` | 격리된 워크스페이스 필요 시 | superpowers | git worktree 기반 격리 워크스페이스 보장 |

### 디버깅·진단

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `superpowers:systematic-debugging` | 버그/테스트 실패 시 | superpowers | 픽스 제안 전 체계적 디버깅 |
| `diagnose` | 어려운 버그/성능 회귀 진단 시 | mattpocock/skills | 재현 → 최소화 → 가설 → 계측 → 수정 → 회귀 테스트 루프 |
| `mobile-view-debugger` | 모바일 뷰 문제 진단 요청 시 | custom | 모바일 에뮬레이션 + 자동 진단(오버플로우, 터치 타겟 등) |
| `measure-rerender` | 리렌더링 성능 측정 요청 시 | custom | React 컴포넌트 리렌더링 횟수 측정 및 비교 분석 |
| `chrome-devtools-mcp:memory-leak-debugging` | 메모리 누수 진단 요청 시 | chrome-devtools-mcp | JS/Node.js 메모리 누수 진단 (heapsnapshot, memlab 활용) |
| `chrome-devtools-mcp:debug-optimize-lcp` | LCP/Core Web Vitals 최적화 요청 시 | chrome-devtools-mcp | Largest Contentful Paint 디버깅 및 최적화 가이드 |
| `chrome-devtools-mcp:a11y-debugging` | 접근성 진단 요청 시 | chrome-devtools-mcp | 시맨틱 HTML, ARIA, 키보드 네비게이션, 명도 대비 점검 |
| `chrome-devtools-mcp:troubleshooting` | MCP 연결/타깃 문제 발생 시 | chrome-devtools-mcp | Chrome DevTools MCP 연결 문제 해결 |

### 검증·완료

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `validate-ui` | UI 변경 후 검증 요청 시 | custom | Chrome DevTools MCP를 사용한 4계층 검증(A11y Snapshot, Screenshot, DOM Query, Runtime Logs) |
| `verify` | PR/로컬 변경 동작 확인 시 | built-in | 앱을 실행해 코드 변경이 실제 의도대로 동작하는지 검증 |
| `run` | 앱을 실행해 결과 확인 시 | built-in | 프로젝트 앱을 띄워 변경사항을 실 환경에서 확인 |
| `superpowers:verification-before-completion` | 완료 선언 직전 | superpowers | 완료/통과 주장 전 검증 명령 실행 |
| `document-skills:webapp-testing` | 로컬 웹앱 테스트 요청 시 | document-skills | Playwright 기반 로컬 웹앱 동작 검증 |
| `chrome-devtools-mcp:chrome-devtools` | 브라우저 디버깅/자동화 시 | chrome-devtools-mcp | Chrome DevTools MCP 기반 범용 브라우저 디버깅 |
| `chrome-devtools-mcp:chrome-devtools-cli` | 브라우저 자동화 스크립트 작성 시 | chrome-devtools-mcp | CLI에서 Chrome DevTools 자동화 |
| `superpowers:requesting-code-review` | 작업 완료/머지 직전 | superpowers | 요구사항 충족 검증을 위한 코드 리뷰 요청 |
| `superpowers:receiving-code-review` | 코드 리뷰 피드백 수신 시 | superpowers | 피드백 검증 후 적용 (맹목적 동의 금지) |
| `superpowers:finishing-a-development-branch` | 구현 완료 후 브랜치 정리 시 | superpowers | 머지/PR/정리 옵션 제시 |

### 코드 리뷰·리팩토링

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `review` | `/review` | built-in | PR 리뷰 |
| `code-review:code-review` | `/code-review` | code-review | PR 코드 리뷰 수행 |
| `code-review` | `/code-review` (현재 diff 대상) | built-in | 현재 변경 diff를 effort 수준별로 검토 |
| `security-review` | `/security-review` | built-in | 현재 브랜치의 변경사항 보안 리뷰 |
| `simplify` | `/simplify` | built-in | 변경된 코드의 재사용/품질/효율 검토 후 수정 |
| `web-design-guidelines` | UI 코드 가이드라인 준수 리뷰 시 | vercel-labs/agent-skills | 웹 인터페이스 가이드라인(접근성/UX/디자인) 기준으로 UI 코드 감사 |
| `vercel-composition-patterns` | React 컴포넌트 합성 패턴 적용 시 | vercel-labs/agent-skills | 컴파운드 컴포넌트·render props·context provider 등 확장형 컴포넌트 API 설계 (React 19 포함) |
| `vercel-react-best-practices` | React/Next.js 성능 작업 시 | vercel-labs/agent-skills | Vercel Engineering의 React/Next.js 성능 최적화 가이드라인 |
| `vercel-react-view-transitions` | React View Transition API 사용 시 | vercel-labs/agent-skills | `<ViewTransition>`·`addTransitionType` 기반 페이지/요소 전환 애니메이션 구현 |
| `improve-codebase-architecture` | 아키텍처 개선/리팩토링 기회 탐색 시 | mattpocock/skills | CONTEXT.md/ADR 기반 deepening 기회 도출 |
| `zoom-out` | 더 넓은 맥락 요청 시 | mattpocock/skills | 상위 관점에서 코드 구조와 맥락 설명 |

### 문서화 (코드→문서)

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `write-app-spec` | `/write-app-spec` | custom | 프론트엔드/풀스택 앱의 코드베이스를 분석하여 화면, 라우팅, 핵심 로직, 데이터 모델을 문서화한 SPEC.md 생성 |
| `write-nestjs-spec` | `/write-nestjs-spec {모듈명}` | custom | NestJS 백엔드 모듈 API 스펙 문서 생성 |
| `handoff` | 다른 에이전트로 인계 시 | mattpocock/skills | 현재 대화를 핸드오프 문서로 압축 |
| `mine-session-decisions` | `/mine-session-decisions` | custom | 과거 세션 .jsonl에서 설계 결정·요구사항 해석·가정을 마이닝하여 문서 후보 추출 |
| `humanizer` | AI 작성 흔적 제거 요청 시 | custom | AI 생성 텍스트의 패턴(과장 상징, 홍보성 문구, em dash 남발 등)을 검출하고 자연스럽게 교정 |
| `document-skills:doc-coauthoring` | 문서 공동 작성 요청 시 | document-skills | 구조화된 문서/제안서/스펙 공동 작성 워크플로우 |
| `document-skills:internal-comms` | 사내 커뮤니케이션 작성 요청 시 | document-skills | 상태 보고, 리더십 업데이트 등 내부 커뮤니케이션 작성 |

### 디자인·UI 생성

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `frontend-design:frontend-design` | 프론트엔드 UI 생성 요청 시 | frontend-design | 프로덕션급 디자인 품질의 프론트엔드 인터페이스 생성 |
| `document-skills:frontend-design` | 웹 컴포넌트/페이지 빌드 요청 시 | document-skills | 동일 계열의 frontend-design 스킬 (document-skills 마켓플레이스 버전) |
| `document-skills:web-artifacts-builder` | 복잡한 HTML 아티팩트 빌드 시 | document-skills | React/Tailwind/shadcn 기반 다중 컴포넌트 아티팩트 |
| `ui-ux-pro-max:ui-ux-pro-max` | UI/UX 설계/구현 요청 시 | ui-ux-pro-max | 50+ 스타일, 161 컬러 팔레트, 57 폰트 페어링 등 디자인 인텔리전스 |
| `document-skills:theme-factory` | 아티팩트 테마 적용 요청 시 | document-skills | 슬라이드/문서/HTML 아티팩트에 사전 정의된 테마 적용 |
| `document-skills:brand-guidelines` | 브랜드 가이드 적용 요청 시 | document-skills | Anthropic 공식 브랜드 색상/타이포 적용 |
| `document-skills:canvas-design` | 포스터/시각 아트 생성 요청 시 | document-skills | .png/.pdf 기반 비주얼 아트 생성 |
| `document-skills:algorithmic-art` | 알고리즈믹 아트 요청 시 | document-skills | p5.js 기반 제너러티브 아트 생성 |
| `document-skills:slack-gif-creator` | Slack용 GIF 생성 요청 시 | document-skills | Slack 최적화 애니메이션 GIF 생성 |
| `ui-ux-pro-max:ckm:design` | 로고/CIP/슬라이드/배너/아이콘 등 종합 디자인 요청 시 | ui-ux-pro-max | 브랜드 아이덴티티·디자인 토큰·UI 스타일링·로고·CIP·HTML 슬라이드·배너·아이콘·소셜 이미지 통합 디자인 |
| `ui-ux-pro-max:ckm:design-system` | 디자인 토큰/시스템 구축 요청 시 | ui-ux-pro-max | 3계층 토큰(primitive→semantic→component), 컴포넌트 스펙, 전략적 슬라이드 생성 |
| `ui-ux-pro-max:ckm:ui-styling` | shadcn/ui + Tailwind UI 구현 시 | ui-ux-pro-max | shadcn/ui·Tailwind 기반 접근성 UI 및 캔버스 비주얼 디자인 |
| `ui-ux-pro-max:ckm:brand` | 브랜드 보이스/가이드 작성 시 | ui-ux-pro-max | 브랜드 보이스·비주얼 아이덴티티·메시징 프레임워크·자산 일관성 |
| `ui-ux-pro-max:ckm:banner-design` | 소셜/광고/웹 배너 디자인 시 | ui-ux-pro-max | 소셜미디어·광고·웹 히어로·인쇄용 배너를 다양한 아트 디렉션으로 생성 |
| `ui-ux-pro-max:ckm:slides` | 전략적 HTML 프레젠테이션 생성 시 | ui-ux-pro-max | Chart.js·디자인 토큰·카피라이팅 공식 기반 반응형 HTML 슬라이드 |

### 오피스 문서 생성

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `document-skills:docx` | .docx 파일 작업 요청 시 | document-skills | Word 문서 생성/편집/추출 |
| `document-skills:pptx` | .pptx 파일 작업 요청 시 | document-skills | PowerPoint 슬라이드 덱 생성/편집 |
| `document-skills:xlsx` | 스프레드시트 작업 요청 시 | document-skills | Excel(.xlsx/.csv 등) 생성/편집/정제 |
| `document-skills:pdf` | PDF 작업 요청 시 | document-skills | PDF 읽기/병합/분할/OCR 등 |

### 외부 도구 연동

#### Slack

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `slack:slack-messaging` | Slack 메시지 작성 시 | slack | Slack용 마크다운 포맷팅 가이드 |
| `slack:slack-search` | Slack 검색 시 | slack | 메시지/파일/채널/사람 검색 가이드 |
| `slack:summarize-channel` | 채널 요약 요청 시 | slack | 특정 채널 최근 활동 요약 |
| `slack:channel-digest` | 여러 채널 다이제스트 요청 시 | slack | 여러 채널 활동을 한 번에 요약 |
| `slack:find-discussions` | 특정 주제 논의 찾기 요청 시 | slack | 채널 전반에서 토픽 관련 논의 검색 |
| `slack:draft-announcement` | 공지 초안 작성 요청 시 | slack | 잘 포맷팅된 공지 초안 작성 후 저장 |
| `slack:standup` | 스탠드업 업데이트 요청 시 | slack | 최근 Slack 활동 기반 스탠드업 생성 |

#### Notion

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `Notion:search` | Notion 검색 요청 시 | Notion | Notion 워크스페이스 검색 |
| `Notion:find` | Notion 페이지/DB 찾기 요청 시 | Notion | 키워드로 페이지/DB 빠르게 찾기 |
| `Notion:create-page` | Notion 페이지 생성 요청 시 | Notion | 새 페이지 생성 |
| `Notion:create-database-row` | DB 행 추가 요청 시 | Notion | 자연어 속성값으로 DB에 행 삽입 |
| `Notion:create-task` | Notion 태스크 생성 요청 시 | Notion | 태스크 DB에 새 태스크 생성 |
| `Notion:database-query` | DB 조회 요청 시 | Notion | DB 쿼리 후 구조화된 결과 반환 |
| `Notion:tasks:setup` | 태스크 보드 셋업 요청 시 | Notion | Notion 태스크 보드 초기 구성 |
| `Notion:tasks:plan` | 태스크 플래닝 요청 시 | Notion | Notion 페이지 URL 기반 플래닝 |
| `Notion:tasks:build` | 태스크 빌드 요청 시 | Notion | Notion 페이지 URL 기반 태스크 구축 |
| `Notion:tasks:explain-diff` | 코드 변경 설명 문서 작성 시 | Notion | 코드 변경 내용을 설명하는 Notion 문서 생성 |

#### Atlassian (Jira/Confluence)

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `atlassian:capture-tasks-from-meeting-notes` | 회의록 기반 Jira 태스크 생성 시 | atlassian | 회의록에서 액션 아이템 추출하여 Jira 태스크 생성 |
| `atlassian:generate-status-report` | 프로젝트 상태 보고서 작성 시 | atlassian | Jira 이슈 기반 상태 보고서 생성 및 Confluence 게시 |
| `atlassian:search-company-knowledge` | 사내 지식 검색 요청 시 | atlassian | Confluence/Jira 등 사내 지식 베이스 통합 검색 |
| `atlassian:spec-to-backlog` | 스펙 → Jira 백로그 변환 시 | atlassian | Confluence 스펙 문서를 Epic + 구현 티켓으로 변환 |
| `atlassian:triage-issue` | 버그 트리아지 요청 시 | atlassian | Jira에서 중복 검색 후 신규 이슈 생성/기존 이슈 코멘트 |

### Claude API·MCP 빌드

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `claude-api` | Anthropic SDK 코드 작업 시 | built-in | Claude API/Anthropic SDK 앱 구축·디버깅·최적화 |
| `document-skills:claude-api` | 동일 | document-skills | 동일 스킬의 document-skills 마켓플레이스 버전 |
| `document-skills:mcp-builder` | MCP 서버 구축 요청 시 | document-skills | 고품질 MCP 서버 생성 가이드 |

### 하네스·스킬 관리

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `superpowers:using-superpowers` | 모든 대화 시작 시 | superpowers | superpowers 스킬 사용법 안내 |
| `superpowers:writing-skills` | 스킬 작성/편집/검증 시 | superpowers | 신규 스킬 작성/편집 가이드 |
| `claude-md-management:claude-md-improver` | CLAUDE.md 감사/개선 요청 시 | claude-md-management | 레포의 CLAUDE.md 파일 품질 평가 및 개선 |
| `claude-md-management:revise-claude-md` | 세션 학습 반영 요청 시 | claude-md-management | 세션 학습을 CLAUDE.md에 반영 |
| `skill-creator:skill-creator` | 스킬 생성/수정/평가 요청 시 | skill-creator | 신규 스킬 생성, 기존 스킬 개선, 변량 분석 기반 성능 벤치마크 |
| `document-skills:skill-creator` | 스킬 생성/평가 요청 시 | document-skills | document-skills 마켓플레이스의 스킬 생성기 |
| `find-skills` | 스킬 검색/설치 요청 시 | custom | 설치 가능한 스킬 발견 |
| `setup-matt-pocock-skills` | 엔지니어링 스킬 초기 설정 시 | mattpocock/skills | AGENTS.md/CLAUDE.md에 이슈 트래커·트리아지 라벨·도메인 문서 블록 셋업 |
| `init` | `/init` | built-in | CLAUDE.md 초기 생성 |

### 환경·자동화

| 스킬 | 트리거 | 소속 | 설명 |
|------|--------|------|------|
| `update-config` | settings.json 변경 요청 시 | built-in | 권한, 환경 변수, 훅 등 settings 구성 |
| `keybindings-help` | 키바인딩 커스터마이즈 요청 시 | built-in | `~/.claude/keybindings.json` 수정 |
| `fewer-permission-prompts` | 권한 프롬프트 최소화 요청 시 | built-in | 자주 쓰는 read-only 명령을 allowlist로 추가 |
| `loop` | 반복 실행 요청 시 | built-in | 프롬프트/슬래시 명령을 주기적으로 실행 |
<!-- AUTO:END skills -->

---

## 훅 (Hooks)

<!-- AUTO:BEGIN hooks -->
| 이벤트 | 실행 명령 | 비동기 | 설명 |
|--------|-----------|--------|------|
| `ConfigChange` | `node "$DOTCLAUDE_DIR/scripts/harness-sync/harness-sync.mjs"` | ❌ (sync) | 설정 변경 시 HARNESS.md 자동 갱신 (fingerprint로 게이트) |
| `Notification` | `node "$DOTCLAUDE_DIR/scripts/hooks/notify.mjs"` | ❌ (sync) | Claude Code 알림 발생 시 notify.mjs 실행 |
| `PostToolUse` | `jq -r '.tool_input.file_path' \| xargs npx prettier --write` | ❌ (sync) | 파일 수정 후 prettier로 자동 포맷팅 |
<!-- AUTO:END hooks -->

---

## MCP 서버 (MCP Servers)

User-scope MCP 서버([`mcp-servers.json`](mcp-servers.json))와 활성 플러그인이 번들한 MCP 서버를 통합한 목록입니다.

<!-- AUTO:BEGIN mcps -->
| 서버 | 타입 | 엔드포인트 | 설명 |
|------|------|------------|------|
| `aws-knowledge` | http | `https://knowledge-mcp.global.api.aws` | AWS 공식 문서/지식 베이스 조회 |
| `context7` | stdio | `npx -y @upstash/context7-mcp` | 라이브러리/프레임워크 최신 문서 조회 (context7 플러그인 번들) |
| `playwright` | stdio | `npx @playwright/mcp@latest` | 브라우저 자동화 및 E2E 테스트 (playwright 플러그인 번들) |
| `atlassian` | (번들) | — | Jira/Confluence 연동 (atlassian 플러그인 번들) |
| `notion` | (번들) | — | Notion 워크스페이스 연동 (notion 플러그인 번들) |
| `slack` | (번들) | — | Slack 워크스페이스 연동 (slack 플러그인 번들) |
<!-- AUTO:END mcps -->

---

## 글로벌 인스트럭션 (CLAUDE.md)

```
- 스킬 생성 시 `--path`는 항상 `~/.claude/skills`를 사용할 것
```
