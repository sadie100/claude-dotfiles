# Claude Code Harness 구성 현황

<!-- harness-sync-fingerprint: 4bdd1483bd7a6e9decfa399ec6c056cb2895830bde1fd7fcbf2b2e38316637f5 -->

이 레포지토리에 설치된 Claude Code 설정(스킬, 플러그인, 훅, MCP 등)을 정리한 문서입니다.

> 플러그인 / 스킬 / 훅 섹션은 `scripts/harness-sync/harness-sync.mjs`가 자동으로 갱신합니다.
> 마커(`<!-- AUTO:BEGIN ... -->` / `<!-- AUTO:END ... -->`) 사이는 직접 수정하지 마세요.
> 모델·권한 정보는 [`settings.json`](settings.json)에서 직접 확인하세요.

---

## 플러그인 (Enabled Plugins)

<!-- AUTO:BEGIN plugins -->

### Official Plugins (`claude-plugins-official`)

| 플러그인               | 상태      | 설명                                                   |
| ---------------------- | --------- | ------------------------------------------------------ |
| `context7`             | ✅ 활성   | 라이브러리/프레임워크 최신 문서 조회                   |
| `code-simplifier`      | ✅ 활성   | 코드 단순화 및 리팩토링                                |
| `code-review`          | ✅ 활성   | PR 코드 리뷰                                           |
| `feature-dev`          | ✅ 활성   | 코드베이스 분석 기반 기능 개발 가이드                  |
| `frontend-design`      | ✅ 활성   | 프로덕션급 프론트엔드 UI 생성                          |
| `figma`                | ✅ 활성   | Figma MCP 서버 및 공통 워크플로우 스킬 포함            |
| `typescript-lsp`       | ✅ 활성   | TypeScript 언어 서버 지원                              |
| `playwright`           | ✅ 활성   | 브라우저 자동화 및 테스트                              |
| `chrome-devtools-mcp`  | ✅ 활성   | Chrome 브라우저 제어/검사 MCP (공식 마켓플레이스 버전) |
| `superpowers`          | ✅ 활성   | 확장 기능 모음                                         |
| `security-guidance`    | ✅ 활성   | 보안 가이드라인 제공                                   |
| `claude-md-management` | ✅ 활성   | CLAUDE.md 파일 관리/개선                               |
| `skill-creator`        | ✅ 활성   | 스킬 생성/수정/평가                                    |
| `atlassian`            | ✅ 활성   | Jira/Confluence 연동                                   |
| `notion`               | ✅ 활성   | Notion 연동                                            |
| `slack`                | ✅ 활성   | Slack 연동                                             |
| `ralph-loop`           | ❌ 비활성 | 반복 실행 루프                                         |

### Anthropic Agent Skills (`anthropic-agent-skills`)

| 플러그인          | 상태    | 설명                                                |
| ----------------- | ------- | --------------------------------------------------- |
| `document-skills` | ✅ 활성 | PDF, PPTX, XLSX, 웹 아티팩트 등 문서 관련 스킬 모음 |

### Chrome DevTools (`chrome-devtools-plugins`)

| 플러그인              | 상태    | 설명                                                 |
| --------------------- | ------- | ---------------------------------------------------- |
| `chrome-devtools-mcp` | ✅ 활성 | Chrome DevTools 프로토콜 기반 브라우저 디버깅/자동화 |

### Custom Marketplace (`ui-ux-pro-max-skill`)

| 플러그인        | 상태    | 설명                                                                               |
| --------------- | ------- | ---------------------------------------------------------------------------------- |
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

| 스킬                        | 트리거                              | 소속              | 설명                                                                      |
| --------------------------- | ----------------------------------- | ----------------- | ------------------------------------------------------------------------- |
| `superpowers:brainstorming` | 기능/컴포넌트 설계 시작 시          | superpowers       | 구현 전 사용자 의도/요구사항/설계 탐색                                    |
| `superpowers:writing-plans` | 멀티스텝 작업 계획 작성 시          | superpowers       | 코드 작업 전 구현 계획 작성                                               |
| `dev-prd`                   | `/dev-prd {기능명}`                 | custom            | PRD(제품 요구사항 문서) 작성. 사용자와 협업하여 기능 기획                 |
| `dev-architecture`          | `/dev-architecture {기능명}`        | custom            | 아키텍처 설계. 기술 옵션 분석 및 트레이드오프 제시                        |
| `dev-spec`                  | `/dev-spec {기능명}`                | custom            | 상세 구현 스펙 작성. 인수 조건(AC)을 Given-When-Then 형식으로 정의        |
| `dev-testcase`              | `/dev-testcase {기능명}`            | custom            | 테스트 케이스 자동 도출. 스펙의 AC에서 TC를 생성                          |
| `to-prd`                    | 대화 컨텍스트 → PRD 변환 시         | mattpocock/skills | 현재 대화 맥락을 PRD로 정리하여 이슈 트래커에 게시                        |
| `grill-me`                  | 계획/설계 검증 요청 시              | mattpocock/skills | 계획·설계를 결정 트리 단위로 끝까지 질의하며 검증                         |
| `grill-with-docs`           | 도메인 문서 기반 계획 검증 시       | mattpocock/skills | CONTEXT.md/ADR 기반으로 계획을 검증하고 문서 인라인 갱신                  |
| `grilling`                  | 계획/설계 스트레스 테스트 시        | mattpocock/skills | 'grill' 트리거 구문 기반 인터뷰형 계획 검증                               |
| `codebase-design`           | 모듈 인터페이스 설계/개선 시        | mattpocock/skills | deep module 설계 공용 어휘 — 심화 기회 식별·심층 모듈 결정 보조           |
| `design-an-interface`       | 모듈 API 디자인 비교 탐색 시        | mattpocock/skills | 병렬 서브에이전트로 동일 모듈의 급진적으로 다른 인터페이스 설계 다수 생성 |
| `domain-modeling`           | 도메인 용어/유비쿼터스 언어 정리 시 | mattpocock/skills | DDD 도메인 모델 구축·ADR 기록·도메인 모델 유지                            |
| `ubiquitous-language`       | 도메인 용어집 작성 시               | mattpocock/skills | 대화에서 DDD 유비쿼터스 언어 추출·UBIQUITOUS_LANGUAGE.md 저장             |
| `to-issues`                 | 계획/스펙/PRD → 이슈 분해 시        | mattpocock/skills | 트레이서 불릿 버티컬 슬라이스 기준으로 독립 실행 가능한 이슈로 분해       |
| `spec`                      | `/spec`                             | gstack            | 모호한 의도 → 5단계로 정밀 실행 가능한 스펙 작성                          |
| `plan-ceo-review`           | `/plan-ceo-review`                  | gstack            | CEO/창업자 모드 계획 리뷰                                                 |
| `plan-design-review`        | `/plan-design-review`               | gstack            | 디자이너 시각 계획 리뷰 (인터랙티브)                                      |
| `plan-eng-review`           | `/plan-eng-review`                  | gstack            | 엔지니어링 매니저 모드 계획 리뷰                                          |
| `plan-devex-review`         | `/plan-devex-review`                | gstack            | 개발자 경험(DX) 계획 리뷰 (인터랙티브)                                    |
| `office-hours`              | `/office-hours`                     | gstack            | YC 오피스아워 — 창업자 관점 전략 어드바이스 (두 모드)                     |

### 오케스트레이션·파이프라인

여러 단계/에이전트/스킬을 묶어 한 호출로 자동 실행하는 메타 워크플로우.

| 스킬                                      | 트리거                                       | 소속        | 설명                                                                                                               |
| ----------------------------------------- | -------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------ |
| `front-execute`                           | `/front-execute` (프론트엔드 구현 + 검증 시) | custom      | 문서/지시 입력 → 구현 → 타입체크/유닛테스트 → UI 검증 루프(최대 5회 자동 수정) → 최종 코드 리뷰                    |
| `dev-process`                             | `/dev-process {기능명}`                      | custom      | PRD → 아키텍처 → 스펙 → TC 4단계 오케스트레이터                                                                    |
| `feature-dev:feature-dev`                 | 기능 개발 요청 시                            | feature-dev | 코드베이스 분석 → 설계 → 가이드형 구현을 묶는 멀티스텝 워크플로우                                                  |
| `superpowers:executing-plans`             | 작성된 계획 실행 시                          | superpowers | 리뷰 체크포인트 포함 별도 세션에서 계획 실행                                                                       |
| `superpowers:subagent-driven-development` | 독립 작업이 있는 계획 실행 시                | superpowers | 현재 세션에서 서브에이전트로 독립 작업 실행                                                                        |
| `superpowers:dispatching-parallel-agents` | 독립 작업 2개 이상 시                        | superpowers | 공유 상태 없는 독립 작업 병렬 실행                                                                                 |
| `spec-pipeline`                           | 요구사항→구현 풀 파이프라인 요청 시          | custom      | brainstorming → grilling → writing-plans → executing-plans 4단계 서브에이전트 체인으로 요구사항→구현까지 자동 실행 |
| `autoplan`                                | `/autoplan`                                  | gstack      | CEO·디자인·엔지니어·DX 계획 리뷰를 순차 자동 실행하는 오토 리뷰 파이프라인                                         |
| `ship`                                    | `/ship`                                      | gstack      | 베이스 브랜치 머지·테스트·diff 리뷰·VERSION·CHANGELOG·커밋·푸시·PR을 한 번에                                       |
| `land-and-deploy`                         | `/land-and-deploy`                           | gstack      | 랜드 + 배포 워크플로우                                                                                             |

### 구현

| 스킬                                  | 트리거                           | 소속              | 설명                                                           |
| ------------------------------------- | -------------------------------- | ----------------- | -------------------------------------------------------------- |
| `superpowers:test-driven-development` | 기능/버그픽스 구현 시            | superpowers       | 구현 코드 작성 전 TDD 적용                                     |
| `tdd`                                 | TDD 기반 개발 요청 시            | mattpocock/skills | red-green-refactor 루프 기반 테스트 우선 개발                  |
| `superpowers:using-git-worktrees`     | 격리된 워크스페이스 필요 시      | superpowers       | git worktree 기반 격리 워크스페이스 보장                       |
| `implement`                           | PRD/이슈 기반 구현 요청 시       | mattpocock/skills | PRD나 이슈 묶음을 기반으로 작업 구현                           |
| `prototype`                           | 디자인 탐색용 프로토타입 요청 시 | mattpocock/skills | 일회용 프로토타입(터미널 앱 또는 단일 라우트의 UI 변형들) 빌드 |
| `resolving-merge-conflicts`           | 머지/리베이스 충돌 해결 시       | mattpocock/skills | 진행 중인 git 머지/리베이스 충돌 해소 가이드                   |
| `codex`                               | `/codex`                         | gstack            | OpenAI Codex CLI 래퍼 — 3가지 모드                             |

### 디버깅·진단

| 스킬                                        | 트리거                             | 소속                | 설명                                                    |
| ------------------------------------------- | ---------------------------------- | ------------------- | ------------------------------------------------------- |
| `superpowers:systematic-debugging`          | 버그/테스트 실패 시                | superpowers         | 픽스 제안 전 체계적 디버깅                              |
| `diagnose`                                  | 어려운 버그/성능 회귀 진단 시      | mattpocock/skills   | 재현 → 최소화 → 가설 → 계측 → 수정 → 회귀 테스트 루프   |
| `diagnosing-bugs`                           | 버그/성능 문제 진단 시             | mattpocock/skills   | "diagnose/debug this" 트리거형 진단 루프                |
| `mobile-view-debugger`                      | 모바일 뷰 문제 진단 요청 시        | custom              | 모바일 에뮬레이션 + 자동 진단(오버플로우, 터치 타겟 등) |
| `measure-rerender`                          | 리렌더링 성능 측정 요청 시         | custom              | React 컴포넌트 리렌더링 횟수 측정 및 비교 분석          |
| `chrome-devtools-mcp:memory-leak-debugging` | 메모리 누수 진단 요청 시           | chrome-devtools-mcp | JS/Node.js 메모리 누수 진단 (heapsnapshot, memlab 활용) |
| `chrome-devtools-mcp:debug-optimize-lcp`    | LCP/Core Web Vitals 최적화 요청 시 | chrome-devtools-mcp | Largest Contentful Paint 디버깅 및 최적화 가이드        |
| `chrome-devtools-mcp:a11y-debugging`        | 접근성 진단 요청 시                | chrome-devtools-mcp | 시맨틱 HTML, ARIA, 키보드 네비게이션, 명도 대비 점검    |
| `chrome-devtools-mcp:troubleshooting`       | MCP 연결/타깃 문제 발생 시         | chrome-devtools-mcp | Chrome DevTools MCP 연결 문제 해결                      |
| `investigate`                               | `/investigate`                     | gstack              | 루트 코즈 조사 기반 체계적 디버깅                       |

### 검증·완료

| 스킬                                         | 트리거                           | 소속                | 설명                                                                                        |
| -------------------------------------------- | -------------------------------- | ------------------- | ------------------------------------------------------------------------------------------- |
| `validate-ui`                                | UI 변경 후 검증 요청 시          | custom              | Chrome DevTools MCP를 사용한 4계층 검증(A11y Snapshot, Screenshot, DOM Query, Runtime Logs) |
| `cafe24-preview`                             | `/cafe24-preview`                | custom              | 배포 전 로컬 워킹트리 CSS/JS 변경을 라이브 Cafe24 페이지에 주입해 미리보기                  |
| `cafe24-update`                              | `/cafe24-update`                 | custom              | Cafe24 프로젝트 UI를 Figma 시안과 비교·브라우저 검증 (테스트 서버 URL + Figma 노드)         |
| `gstack`                                     | QA 테스트/사이트 도그푸딩 시     | custom              | 빠른 헤드리스 브라우저로 QA 테스트 및 사이트 도그푸딩 수행                                  |
| `verify`                                     | PR/로컬 변경 동작 확인 시        | built-in            | 앱을 실행해 코드 변경이 실제 의도대로 동작하는지 검증                                       |
| `run`                                        | 앱을 실행해 결과 확인 시         | built-in            | 프로젝트 앱을 띄워 변경사항을 실 환경에서 확인                                              |
| `superpowers:verification-before-completion` | 완료 선언 직전                   | superpowers         | 완료/통과 주장 전 검증 명령 실행                                                            |
| `document-skills:webapp-testing`             | 로컬 웹앱 테스트 요청 시         | document-skills     | Playwright 기반 로컬 웹앱 동작 검증                                                         |
| `chrome-devtools-mcp:chrome-devtools`        | 브라우저 디버깅/자동화 시        | chrome-devtools-mcp | Chrome DevTools MCP 기반 범용 브라우저 디버깅                                               |
| `chrome-devtools-mcp:chrome-devtools-cli`    | 브라우저 자동화 스크립트 작성 시 | chrome-devtools-mcp | CLI에서 Chrome DevTools 자동화                                                              |
| `superpowers:requesting-code-review`         | 작업 완료/머지 직전              | superpowers         | 요구사항 충족 검증을 위한 코드 리뷰 요청                                                    |
| `superpowers:receiving-code-review`          | 코드 리뷰 피드백 수신 시         | superpowers         | 피드백 검증 후 적용 (맹목적 동의 금지)                                                      |
| `superpowers:finishing-a-development-branch` | 구현 완료 후 브랜치 정리 시      | superpowers         | 머지/PR/정리 옵션 제시                                                                      |

### 코드 리뷰·리팩토링

| 스킬                            | 트리거                              | 소속                     | 설명                                                                                        |
| ------------------------------- | ----------------------------------- | ------------------------ | ------------------------------------------------------------------------------------------- |
| `review`                        | `/review`                           | built-in                 | PR 리뷰                                                                                     |
| `code-review:code-review`       | `/code-review`                      | code-review              | PR 코드 리뷰 수행                                                                           |
| `code-review`                   | `/code-review` (현재 diff 대상)     | built-in                 | 현재 변경 diff를 effort 수준별로 검토                                                       |
| `security-review`               | `/security-review`                  | built-in                 | 현재 브랜치의 변경사항 보안 리뷰                                                            |
| `simplify`                      | `/simplify`                         | built-in                 | 변경된 코드의 재사용/품질/효율 검토 후 수정                                                 |
| `web-design-guidelines`         | UI 코드 가이드라인 준수 리뷰 시     | vercel-labs/agent-skills | 웹 인터페이스 가이드라인(접근성/UX/디자인) 기준으로 UI 코드 감사                            |
| `vercel-composition-patterns`   | React 컴포넌트 합성 패턴 적용 시    | vercel-labs/agent-skills | 컴파운드 컴포넌트·render props·context provider 등 확장형 컴포넌트 API 설계 (React 19 포함) |
| `vercel-react-best-practices`   | React/Next.js 성능 작업 시          | vercel-labs/agent-skills | Vercel Engineering의 React/Next.js 성능 최적화 가이드라인                                   |
| `vercel-react-view-transitions` | React View Transition API 사용 시   | vercel-labs/agent-skills | `<ViewTransition>`·`addTransitionType` 기반 페이지/요소 전환 애니메이션 구현                |
| `improve-codebase-architecture` | 아키텍처 개선/리팩토링 기회 탐색 시 | mattpocock/skills        | CONTEXT.md/ADR 기반 deepening 기회 도출                                                     |
| `zoom-out`                      | 더 넓은 맥락 요청 시                | mattpocock/skills        | 상위 관점에서 코드 구조와 맥락 설명                                                         |
| `triage`                        | 이슈/외부 PR 트리아지 시            | mattpocock/skills        | 트리아지 역할 상태머신으로 이슈/PR을 분류·검증·에이전트 브리프 작성                         |
| `devex-review`                  | `/devex-review`                     | gstack                   | 라이브 개발자 경험(DX) 감사                                                                 |
| `health`                        | `/health`                           | gstack                   | 코드 품질 대시보드                                                                          |
| `retro`                         | `/retro`                            | gstack                   | 주간 엔지니어링 회고                                                                        |

### 문서화·도식화

| 스킬                              | 트리거                                  | 소속              | 설명                                                                                                      |
| --------------------------------- | --------------------------------------- | ----------------- | --------------------------------------------------------------------------------------------------------- |
| `write-app-spec`                  | `/write-app-spec`                       | custom            | 프론트엔드/풀스택 앱의 코드베이스를 분석하여 화면, 라우팅, 핵심 로직, 데이터 모델을 문서화한 SPEC.md 생성 |
| `write-nestjs-spec`               | `/write-nestjs-spec {모듈명}`           | custom            | NestJS 백엔드 모듈 API 스펙 문서 생성                                                                     |
| `handoff`                         | 다른 에이전트로 인계 시                 | mattpocock/skills | 현재 대화를 핸드오프 문서로 압축                                                                          |
| `mine-session-decisions`          | `/mine-session-decisions`               | custom            | 과거 세션 .jsonl에서 설계 결정·요구사항 해석·가정을 마이닝하여 문서 후보 추출                             |
| `excalidraw-diagram`              | 워크플로우/아키텍처/개념 시각화 요청 시 | custom            | 워크플로우·아키텍처·개념을 시각적으로 설명하는 Excalidraw 다이어그램 JSON 생성                            |
| `figma:figma-generate-diagram`    | Figma에 다이어그램 생성 요청 시         | figma             | `generate_diagram` 호출 전 필수 로드 — FigJam에 Mermaid 기반 플로우차트/아키텍처/시퀀스/ERD 생성          |
| `humanizer`                       | AI 작성 흔적 제거 요청 시               | custom            | AI 생성 텍스트의 패턴(과장 상징, 홍보성 문구, em dash 남발 등)을 검출하고 자연스럽게 교정                 |
| `document-skills:doc-coauthoring` | 문서 공동 작성 요청 시                  | document-skills   | 구조화된 문서/제안서/스펙 공동 작성 워크플로우                                                            |
| `document-skills:internal-comms`  | 사내 커뮤니케이션 작성 요청 시          | document-skills   | 상태 보고, 리더십 업데이트 등 내부 커뮤니케이션 작성                                                      |
| `diagram`                         | `/diagram`                              | gstack            | 영어 설명/머메이드 소스 → 다이어그램 트리플릿(소스 + 편집 가능 파일)                                      |
| `document-generate`               | `/document-generate`                    | gstack            | 기능/모듈/프로젝트 문서를 처음부터 생성                                                                   |
| `document-release`                | `/document-release`                     | gstack            | 배포 후 문서 갱신                                                                                         |
| `make-pdf`                        | `/make-pdf`                             | gstack            | 마크다운 파일 → 출판 품질 PDF                                                                             |
| `edit-article`                    | 아티클 편집/개선 요청 시                | mattpocock/skills | 섹션 재구성·명확성 개선·문장 다듬기로 아티클 초안 개선                                                    |
| `teach`                           | 새 스킬/개념 학습 요청 시               | mattpocock/skills | 워크스페이스 내에서 사용자에게 새 스킬/개념 교육                                                          |
| `writing-great-skills`            | 스킬 작성 가이드 참조 시                | mattpocock/skills | 좋은 스킬을 쓰기 위한 어휘·원칙 레퍼런스                                                                  |

### 디자인·UI 생성

| 스킬                                    | 트리거                                               | 소속            | 설명                                                                                                 |
| --------------------------------------- | ---------------------------------------------------- | --------------- | ---------------------------------------------------------------------------------------------------- |
| `frontend-design:frontend-design`       | 프론트엔드 UI 생성 요청 시                           | frontend-design | 프로덕션급 디자인 품질의 프론트엔드 인터페이스 생성                                                  |
| `document-skills:frontend-design`       | 웹 컴포넌트/페이지 빌드 요청 시                      | document-skills | 동일 계열의 frontend-design 스킬 (document-skills 마켓플레이스 버전)                                 |
| `document-skills:web-artifacts-builder` | 복잡한 HTML 아티팩트 빌드 시                         | document-skills | React/Tailwind/shadcn 기반 다중 컴포넌트 아티팩트                                                    |
| `ui-ux-pro-max:ui-ux-pro-max`           | UI/UX 설계/구현 요청 시                              | ui-ux-pro-max   | 50+ 스타일, 161 컬러 팔레트, 57 폰트 페어링 등 디자인 인텔리전스                                     |
| `document-skills:theme-factory`         | 아티팩트 테마 적용 요청 시                           | document-skills | 슬라이드/문서/HTML 아티팩트에 사전 정의된 테마 적용                                                  |
| `document-skills:brand-guidelines`      | 브랜드 가이드 적용 요청 시                           | document-skills | Anthropic 공식 브랜드 색상/타이포 적용                                                               |
| `document-skills:canvas-design`         | 포스터/시각 아트 생성 요청 시                        | document-skills | .png/.pdf 기반 비주얼 아트 생성                                                                      |
| `document-skills:algorithmic-art`       | 알고리즈믹 아트 요청 시                              | document-skills | p5.js 기반 제너러티브 아트 생성                                                                      |
| `document-skills:slack-gif-creator`     | Slack용 GIF 생성 요청 시                             | document-skills | Slack 최적화 애니메이션 GIF 생성                                                                     |
| `ui-ux-pro-max:ckm:design`              | 로고/CIP/슬라이드/배너/아이콘 등 종합 디자인 요청 시 | ui-ux-pro-max   | 브랜드 아이덴티티·디자인 토큰·UI 스타일링·로고·CIP·HTML 슬라이드·배너·아이콘·소셜 이미지 통합 디자인 |
| `ui-ux-pro-max:ckm:design-system`       | 디자인 토큰/시스템 구축 요청 시                      | ui-ux-pro-max   | 3계층 토큰(primitive→semantic→component), 컴포넌트 스펙, 전략적 슬라이드 생성                        |
| `ui-ux-pro-max:ckm:ui-styling`          | shadcn/ui + Tailwind UI 구현 시                      | ui-ux-pro-max   | shadcn/ui·Tailwind 기반 접근성 UI 및 캔버스 비주얼 디자인                                            |
| `ui-ux-pro-max:ckm:brand`               | 브랜드 보이스/가이드 작성 시                         | ui-ux-pro-max   | 브랜드 보이스·비주얼 아이덴티티·메시징 프레임워크·자산 일관성                                        |
| `ui-ux-pro-max:ckm:banner-design`       | 소셜/광고/웹 배너 디자인 시                          | ui-ux-pro-max   | 소셜미디어·광고·웹 히어로·인쇄용 배너를 다양한 아트 디렉션으로 생성                                  |
| `ui-ux-pro-max:ckm:slides`              | 전략적 HTML 프레젠테이션 생성 시                     | ui-ux-pro-max   | Chart.js·디자인 토큰·카피라이팅 공식 기반 반응형 HTML 슬라이드                                       |
| `figma:figma-generate-design`           | 앱 페이지/뷰를 Figma로 변환 요청 시                  | figma           | 앱 페이지·뷰·레이아웃을 디자인 시스템 컴포넌트 기반으로 Figma에 구축 (design-to-Figma)               |
| `figma:figma-generate-library`          | Figma 디자인 시스템 구축 요청 시                     | figma           | 코드베이스에서 Figma 변수/토큰·컴포넌트 라이브러리 구축                                              |
| `figma:figma-code-connect`              | Figma Code Connect 매핑 작업 시                      | figma           | Figma 컴포넌트↔코드 스니펫 매핑(.figma.ts/.figma.js) 생성·관리                                       |
| `figma:figma-implement-motion`          | Figma 모션 구현 요청 시                              | figma           | Figma 모션/애니메이션을 프로덕션 코드로 변환                                                         |
| `figma:figma-swiftui`                   | SwiftUI↔Figma 변환 시                                | figma           | SwiftUI ↔ Figma 양방향 디자인/코드 변환                                                              |
| `figma:figma-create-new-file`           | 새 Figma 파일 생성 전                                | figma           | `create_new_file` 호출 전 필수 로드 — 새 디자인/FigJam/슬라이드 파일 생성                            |
| `figma:figma-use`                       | use_figma 쓰기/실행 작업 전                          | figma           | `use_figma` 호출 전 필수 로드 — 노드 생성/편집·변수·컴포넌트 작업                                    |
| `figma:figma-use-figjam`                | FigJam 컨텍스트 use_figma 사용 시                    | figma           | FigJam 컨텍스트에서 use_figma 툴 사용 보조                                                           |
| `figma:figma-use-motion`                | 노드 애니메이션 작업 시                              | figma           | use_figma 툴로 노드 애니메이션(키프레임/이징/타임라인) 작업                                          |
| `figma:figma-use-slides`                | 슬라이드 컨텍스트 use_figma 사용 시                  | figma           | 슬라이드 컨텍스트에서 use_figma 툴 사용 보조                                                         |
| `design-consultation`                   | `/design-consultation`                               | gstack          | 제품 이해 → 랜드스케이프 리서치 → 디자인 시스템 제안 + 폰트·컬러 프리뷰                              |
| `design-html`                           | `/design-html`                                       | gstack          | 프로덕션급 Pretext-native HTML/CSS 디자인 확정                                                       |
| `design-shotgun`                        | `/design-shotgun`                                    | gstack          | 다중 AI 디자인 변형 생성·비교 보드·피드백·반복                                                       |

### 오피스 문서 생성

| 스킬                   | 트리거                    | 소속            | 설명                                |
| ---------------------- | ------------------------- | --------------- | ----------------------------------- |
| `document-skills:docx` | .docx 파일 작업 요청 시   | document-skills | Word 문서 생성/편집/추출            |
| `document-skills:pptx` | .pptx 파일 작업 요청 시   | document-skills | PowerPoint 슬라이드 덱 생성/편집    |
| `document-skills:xlsx` | 스프레드시트 작업 요청 시 | document-skills | Excel(.xlsx/.csv 등) 생성/편집/정제 |
| `document-skills:pdf`  | PDF 작업 요청 시          | document-skills | PDF 읽기/병합/분할/OCR 등           |

### 외부 도구 연동

#### Slack

| 스킬                       | 트리거                       | 소속  | 설명                               |
| -------------------------- | ---------------------------- | ----- | ---------------------------------- |
| `slack:slack-messaging`    | Slack 메시지 작성 시         | slack | Slack용 마크다운 포맷팅 가이드     |
| `slack:slack-search`       | Slack 검색 시                | slack | 메시지/파일/채널/사람 검색 가이드  |
| `slack:summarize-channel`  | 채널 요약 요청 시            | slack | 특정 채널 최근 활동 요약           |
| `slack:channel-digest`     | 여러 채널 다이제스트 요청 시 | slack | 여러 채널 활동을 한 번에 요약      |
| `slack:find-discussions`   | 특정 주제 논의 찾기 요청 시  | slack | 채널 전반에서 토픽 관련 논의 검색  |
| `slack:draft-announcement` | 공지 초안 작성 요청 시       | slack | 잘 포맷팅된 공지 초안 작성 후 저장 |
| `slack:standup`            | 스탠드업 업데이트 요청 시    | slack | 최근 Slack 활동 기반 스탠드업 생성 |

#### Notion

| 스킬                         | 트리거                        | 소속   | 설명                                       |
| ---------------------------- | ----------------------------- | ------ | ------------------------------------------ |
| `Notion:search`              | Notion 검색 요청 시           | Notion | Notion 워크스페이스 검색                   |
| `Notion:find`                | Notion 페이지/DB 찾기 요청 시 | Notion | 키워드로 페이지/DB 빠르게 찾기             |
| `Notion:create-page`         | Notion 페이지 생성 요청 시    | Notion | 새 페이지 생성                             |
| `Notion:create-database-row` | DB 행 추가 요청 시            | Notion | 자연어 속성값으로 DB에 행 삽입             |
| `Notion:create-task`         | Notion 태스크 생성 요청 시    | Notion | 태스크 DB에 새 태스크 생성                 |
| `Notion:database-query`      | DB 조회 요청 시               | Notion | DB 쿼리 후 구조화된 결과 반환              |
| `Notion:tasks:setup`         | 태스크 보드 셋업 요청 시      | Notion | Notion 태스크 보드 초기 구성               |
| `Notion:tasks:plan`          | 태스크 플래닝 요청 시         | Notion | Notion 페이지 URL 기반 플래닝              |
| `Notion:tasks:build`         | 태스크 빌드 요청 시           | Notion | Notion 페이지 URL 기반 태스크 구축         |
| `Notion:tasks:explain-diff`  | 코드 변경 설명 문서 작성 시   | Notion | 코드 변경 내용을 설명하는 Notion 문서 생성 |

#### Atlassian (Jira/Confluence)

| 스킬                                         | 트리거                          | 소속      | 설명                                                                                         |
| -------------------------------------------- | ------------------------------- | --------- | -------------------------------------------------------------------------------------------- |
| `atlassian:capture-tasks-from-meeting-notes` | 회의록 기반 Jira 태스크 생성 시 | atlassian | 회의록에서 액션 아이템 추출하여 Jira 태스크 생성                                             |
| `atlassian:generate-status-report`           | 프로젝트 상태 보고서 작성 시    | atlassian | Jira 이슈 기반 상태 보고서 생성 및 Confluence 게시                                           |
| `atlassian:search-company-knowledge`         | 사내 지식 검색 요청 시          | atlassian | Confluence/Jira 등 사내 지식 베이스 통합 검색                                                |
| `atlassian:spec-to-backlog`                  | 스펙 → Jira 백로그 변환 시      | atlassian | Confluence 스펙 문서를 Epic + 구현 티켓으로 변환                                             |
| `atlassian:jira-sprint-dashboard-canvas`     | Jira 스프린트 대시보드 생성 시  | atlassian | Jira 프로젝트·스프린트·보드·JQL 데이터로 시각적 스프린트 대시보드(캔버스/HTML/마크다운) 생성 |
| `atlassian:triage-issue`                     | 버그 트리아지 요청 시           | atlassian | Jira에서 중복 검색 후 신규 이슈 생성/기존 이슈 코멘트                                        |

### Claude API·MCP 빌드

| 스킬                          | 트리거                     | 소속            | 설명                                           |
| ----------------------------- | -------------------------- | --------------- | ---------------------------------------------- |
| `claude-api`                  | Anthropic SDK 코드 작업 시 | built-in        | Claude API/Anthropic SDK 앱 구축·디버깅·최적화 |
| `document-skills:claude-api`  | 동일                       | document-skills | 동일 스킬의 document-skills 마켓플레이스 버전  |
| `document-skills:mcp-builder` | MCP 서버 구축 요청 시      | document-skills | 고품질 MCP 서버 생성 가이드                    |

### 하네스·스킬 관리

| 스킬                                      | 트리거                            | 소속                 | 설명                                                                  |
| ----------------------------------------- | --------------------------------- | -------------------- | --------------------------------------------------------------------- |
| `superpowers:using-superpowers`           | 모든 대화 시작 시                 | superpowers          | superpowers 스킬 사용법 안내                                          |
| `superpowers:writing-skills`              | 스킬 작성/편집/검증 시            | superpowers          | 신규 스킬 작성/편집 가이드                                            |
| `claude-md-management:claude-md-improver` | CLAUDE.md 감사/개선 요청 시       | claude-md-management | 레포의 CLAUDE.md 파일 품질 평가 및 개선                               |
| `claude-md-management:revise-claude-md`   | 세션 학습 반영 요청 시            | claude-md-management | 세션 학습을 CLAUDE.md에 반영                                          |
| `skill-creator:skill-creator`             | 스킬 생성/수정/평가 요청 시       | skill-creator        | 신규 스킬 생성, 기존 스킬 개선, 변량 분석 기반 성능 벤치마크          |
| `document-skills:skill-creator`           | 스킬 생성/평가 요청 시            | document-skills      | document-skills 마켓플레이스의 스킬 생성기                            |
| `find-skills`                             | 스킬 검색/설치 요청 시            | custom               | 설치 가능한 스킬 발견                                                 |
| `ask-matt`                                | 상황에 맞는 스킬/플로우 라우팅 시 | mattpocock/skills    | 레포의 사용자 호출 스킬 위에서 동작하는 라우터                        |
| `setup-matt-pocock-skills`                | 엔지니어링 스킬 초기 설정 시      | mattpocock/skills    | AGENTS.md/CLAUDE.md에 이슈 트래커·트리아지 라벨·도메인 문서 블록 셋업 |
| `init`                                    | `/init`                           | built-in             | CLAUDE.md 초기 생성                                                   |

### GEO·SEO 분석

AI 검색(ChatGPT, Claude, Perplexity, Gemini, Google AI Overviews) 가시성 최적화 도메인 스킬 모음.

| 스킬                     | 트리거                           | 소속   | 설명                                                                                           |
| ------------------------ | -------------------------------- | ------ | ---------------------------------------------------------------------------------------------- |
| `geo`                    | GEO/SEO/AI 가시성 분석 요청 시   | custom | GEO 우선 SEO 분석 도구. 풀 감사·인용성·크롤러·llms.txt·브랜드 멘션·플랫폼별 최적화 통합 진입점 |
| `geo-audit`              | 전체 GEO+SEO 감사 요청 시        | custom | 병렬 서브에이전트 기반 풀 감사. 합산 GEO Score(0-100) 및 우선순위 액션 플랜 생성               |
| `geo-citability`         | AI 인용 가능성 점수화 요청 시    | custom | 페이지 콘텐츠가 AI에 인용될 가능성을 점수화하고 리라이트 제안                                  |
| `geo-brand-mentions`     | 브랜드 멘션/권위 분석 요청 시    | custom | AI가 신뢰하는 플랫폼 전반의 브랜드 권위 스캐너 (Brand Authority Score)                         |
| `geo-crawlers`           | AI 크롤러 접근성 분석 요청 시    | custom | robots.txt/메타/헤더로 AI 크롤러 접근 가능성 매핑                                              |
| `geo-llmstxt`            | llms.txt 분석/생성 요청 시       | custom | llms.txt 유효성 검사 또는 사이트 크롤로 신규 생성                                              |
| `geo-platform-optimizer` | 플랫폼별 AI 검색 최적화 요청 시  | custom | Google AI Overviews·ChatGPT·Perplexity·Gemini·Bing Copilot 개별 최적화                         |
| `geo-content`            | E-E-A-T 콘텐츠 품질 평가 요청 시 | custom | Experience/Expertise/Authoritativeness/Trustworthiness 기준 콘텐츠 품질 평가                   |
| `geo-schema`             | Schema.org 구조화 데이터 작업 시 | custom | AI 발견성을 위한 JSON-LD 마크업 감사·생성                                                      |
| `geo-technical`          | 테크니컬 SEO 감사 요청 시        | custom | 크롤러빌리티·인덱서빌리티·보안·성능·SSR 등 GEO 특화 테크니컬 감사                              |
| `geo-compare`            | 월간 GEO 진행 비교 요청 시       | custom | 베이스라인 vs 현재 감사 델타 추적 및 클라이언트 진행 리포트                                    |
| `geo-report`             | GEO 클라이언트 리포트 생성 시    | custom | 감사 결과 종합 클라이언트 대상 리포트(점수·발견·우선순위 액션)                                 |
| `geo-report-pdf`         | GEO 리포트 PDF 변환 요청 시      | custom | pandoc + Chrome headless로 GEO-AUDIT-REPORT.md를 스타일 적용 PDF로 변환                        |
| `geo-proposal`           | GEO 서비스 제안서 생성 요청 시   | custom | 감사 데이터에서 패키지·가격·일정 포함 클라이언트 제안서 자동 생성                              |
| `geo-prospect`           | GEO 프로스펙트/CRM 관리 시       | custom | 리드→Qualified→제안→Won/Lost 파이프라인 CRM                                                    |
| `geo-update`             | GEO 스킬 업데이트 요청 시        | custom | 업스트림 레포에서 GEO 스킬·에이전트·스크립트 최신화                                            |

### 환경·자동화

| 스킬                         | 트리거                        | 소속              | 설명                                                                |
| ---------------------------- | ----------------------------- | ----------------- | ------------------------------------------------------------------- |
| `update-config`              | settings.json 변경 요청 시    | built-in          | 권한, 환경 변수, 훅 등 settings 구성                                |
| `keybindings-help`           | 키바인딩 커스터마이즈 요청 시 | built-in          | `~/.claude/keybindings.json` 수정                                   |
| `fewer-permission-prompts`   | 권한 프롬프트 최소화 요청 시  | built-in          | 자주 쓰는 read-only 명령을 allowlist로 추가                         |
| `loop`                       | 반복 실행 요청 시             | built-in          | 프롬프트/슬래시 명령을 주기적으로 실행                              |
| `git-guardrails-claude-code` | 파괴적 git 명령 차단 셋업 시  | custom            | Claude Code 훅으로 위험한 git 명령(push, reset --hard 등) 사전 차단 |
| `scaffold-exercises`         | 코스 연습문제 스캐폴드 시     | mattpocock/skills | 섹션·문제·솔루션·해설 포함 연습문제 디렉토리 구조 생성(린트 통과)   |

### gstack 전용 (gstack 스택 종속)

gstack의 런타임·인프라(browse 엔진, gstack 브라우저, gbrain, 세션 스토어, iOS 디버그 브리지, gstack 자체 설정)가 있어야 동작하는 스킬. gstack 없이는 의미가 없어 기능 카테고리와 분리한다. 소속은 전부 `gstack`.

#### 브라우저 엔진 (`browse` 기반)

| 스킬                    | 트리거                   | 소속   | 설명                                                          |
| ----------------------- | ------------------------ | ------ | ------------------------------------------------------------- |
| `browse`                | `/browse`                | gstack | 빠른 헤드리스 브라우저로 QA 테스트·사이트 도그푸딩            |
| `qa`                    | `/qa`                    | gstack | 웹 앱 QA 테스트 후 발견된 버그 자동 수정                      |
| `qa-only`               | `/qa-only`               | gstack | 리포트 전용 QA 테스트 (수정 없이 보고만)                      |
| `scrape`                | `/scrape`                | gstack | 웹 페이지에서 데이터 추출                                     |
| `benchmark`             | `/benchmark`             | gstack | browse 데몬 기반 성능 회귀 감지                               |
| `canary`                | `/canary`                | gstack | 배포 후 카나리 모니터링                                       |
| `design-review`         | `/design-review`         | gstack | 디자이너 시각 QA — 시각 불일치·간격·위계·AI 슬롭 탐지 후 수정 |
| `setup-browser-cookies` | `/setup-browser-cookies` | gstack | 실제 Chromium 쿠키를 헤드리스 browse 세션으로 가져오기        |
| `skillify`              | `/skillify`              | gstack | 최근 성공한 `/scrape` 플로우를 영구 브라우저 스킬로 코드화    |

#### gstack 브라우저 앱

| 스킬                  | 트리거                 | 소속   | 설명                                                         |
| --------------------- | ---------------------- | ------ | ------------------------------------------------------------ |
| `open-gstack-browser` | `/open-gstack-browser` | gstack | 사이드바 확장이 포함된 AI 제어 Chromium(GStack Browser) 실행 |
| `pair-agent`          | `/pair-agent`          | gstack | 원격 AI 에이전트를 브라우저에 페어링                         |
| `connect-chrome`      | `/connect-chrome`      | gstack | 기존 Chrome 인스턴스에 gstack 브라우저 도구를 연결           |

#### gbrain (시맨틱 코드 인덱스)

| 스킬           | 트리거          | 소속   | 설명                                                     |
| -------------- | --------------- | ------ | -------------------------------------------------------- |
| `setup-gbrain` | `/setup-gbrain` | gstack | gbrain 설치·초기화(PGLite/Supabase)·MCP 등록             |
| `sync-gbrain`  | `/sync-gbrain`  | gstack | gbrain을 레포 코드와 동기화 + CLAUDE.md 검색 가이드 갱신 |

#### 세이프티·세션 모드

| 스킬              | 트리거             | 소속   | 설명                                                       |
| ----------------- | ------------------ | ------ | ---------------------------------------------------------- |
| `careful`         | `/careful`         | gstack | 파괴적 명령에 대한 안전 가드레일                           |
| `guard`           | `/guard`           | gstack | 풀 세이프티 모드 — 파괴적 명령 경고 + 디렉터리 스코프 편집 |
| `freeze`          | `/freeze`          | gstack | 세션 동안 특정 디렉터리로 편집 제한                        |
| `unfreeze`        | `/unfreeze`        | gstack | `/freeze` 경계 해제                                        |
| `cso`             | `/cso`             | gstack | Chief Security Officer 모드                                |
| `context-save`    | `/context-save`    | gstack | 작업 컨텍스트 저장                                         |
| `context-restore` | `/context-restore` | gstack | `/context-save`로 저장한 컨텍스트 복원                     |
| `learn`           | `/learn`           | gstack | 프로젝트 학습(learnings) 관리                              |

#### iOS 디버그 브리지

| 스킬                | 트리거               | 소속   | 설명                                                        |
| ------------------- | -------------------- | ------ | ----------------------------------------------------------- |
| `ios-qa`            | `/ios-qa`            | gstack | 실기기 SwiftUI iOS 앱 QA                                    |
| `ios-fix`           | `/ios-fix`           | gstack | 자율 iOS 버그 픽서                                          |
| `ios-design-review` | `/ios-design-review` | gstack | 실기기 iOS 앱 시각 디자인 감사                              |
| `ios-sync`          | `/ios-sync`          | gstack | iOS 디버그 브리지를 최신 gstack 템플릿으로 재생성           |
| `ios-clean`         | `/ios-clean`         | gstack | iOS 앱에서 DebugBridge SPM 패키지·`#if DEBUG` 와이어링 제거 |

#### gstack 관리·운영

| 스킬               | 트리거              | 소속   | 설명                                                 |
| ------------------ | ------------------- | ------ | ---------------------------------------------------- |
| `gstack-upgrade`   | `/gstack-upgrade`   | gstack | gstack을 최신 버전으로 업그레이드                    |
| `benchmark-models` | `/benchmark-models` | gstack | gstack 스킬 크로스 모델 벤치마크                     |
| `plan-tune`        | `/plan-tune`        | gstack | 계획 리뷰 질문 민감도 자기튜닝 + 개발자 사이코그래픽 |
| `landing-report`   | `/landing-report`   | gstack | 워크스페이스 인지 ship용 읽기 전용 큐 대시보드       |
| `setup-deploy`     | `/setup-deploy`     | gstack | `/land-and-deploy`용 배포 설정 구성                  |

<!-- AUTO:END skills -->

---

## 훅 (Hooks)

<!-- AUTO:BEGIN hooks -->

| 이벤트         | 실행 명령                                                     | 비동기    | 설명                                                     |
| -------------- | ------------------------------------------------------------- | --------- | -------------------------------------------------------- |
| `ConfigChange` | `node "$DOTCLAUDE_DIR/scripts/harness-sync/harness-sync.mjs"` | ❌ (sync) | 설정 변경 시 HARNESS.md 자동 갱신 (fingerprint로 게이트) |
| `Notification` | `node "$DOTCLAUDE_DIR/scripts/hooks/notify.mjs"`              | ❌ (sync) | Claude Code 알림 발생 시 notify.mjs 실행                 |
| `PostToolUse`  | `jq -r '.tool_input.file_path' \| xargs npx prettier --write` | ❌ (sync) | 파일 수정 후 prettier로 자동 포맷팅                      |

<!-- AUTO:END hooks -->

---

## MCP 서버 (MCP Servers)

User-scope MCP 서버([`mcp-servers.json`](mcp-servers.json))와 활성 플러그인이 번들한 MCP 서버를 통합한 목록입니다.

<!-- AUTO:BEGIN mcps -->

| 서버              | 타입   | 엔드포인트                             | 설명                                                                   |
| ----------------- | ------ | -------------------------------------- | ---------------------------------------------------------------------- |
| `aws-knowledge`   | http   | `https://knowledge-mcp.global.api.aws` | AWS 공식 문서/지식 베이스 조회                                         |
| `context7`        | stdio  | `npx -y @upstash/context7-mcp`         | 라이브러리/프레임워크 최신 문서 조회 (context7 플러그인 번들)          |
| `chrome-devtools` | stdio  | `npx chrome-devtools-mcp@1.4.0`        | Chrome 브라우저 제어/디버깅/자동화 (chrome-devtools-mcp 플러그인 번들) |
| `playwright`      | stdio  | `npx @playwright/mcp@latest`           | 브라우저 자동화 및 E2E 테스트 (playwright 플러그인 번들)               |
| `figma`           | (번들) | —                                      | Figma 디자인 파일 연동 (figma 플러그인 번들)                           |
| `atlassian`       | (번들) | —                                      | Jira/Confluence 연동 (atlassian 플러그인 번들)                         |
| `notion`          | (번들) | —                                      | Notion 워크스페이스 연동 (notion 플러그인 번들)                        |
| `slack`           | (번들) | —                                      | Slack 워크스페이스 연동 (slack 플러그인 번들)                          |

<!-- AUTO:END mcps -->

---

## 글로벌 인스트럭션 (CLAUDE.md)

```
- 스킬 생성 시 `--path`는 항상 `~/.claude/skills`를 사용할 것
```
