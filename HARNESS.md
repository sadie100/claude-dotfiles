# Claude Code Harness 구성 현황

이 레포지토리에 설치된 Claude Code 설정(스킬, 플러그인, 훅, MCP 등)을 정리한 문서입니다.

---

## 모델 설정

| 항목 | 값 |
|------|-----|
| 모델 | `opus[1m]` (Claude Opus, 1M 컨텍스트) |
| Effort Level | `medium` |
| Auto Updates | `latest` |
| Plans Directory | `.claude/plans` |

---

## 플러그인 (Enabled Plugins)

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
| `superpowers` | ✅ 활성 | 확장 기능 모음 |
| `security-guidance` | ✅ 활성 | 보안 가이드라인 제공 |
| `claude-md-management` | ✅ 활성 | CLAUDE.md 파일 관리/개선 |
| `skill-creator` | ✅ 활성 | 스킬 생성/수정/평가 |
| `atlassian` | ✅ 활성 | Jira/Confluence 연동 |
| `Notion` | ✅ 활성 | Notion 연동 |
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

| 플러그인 | 상태 | 소스 | 설명 |
|----------|----|-----|-------------|
| `ui-ux-pro-max` | ✅ 활성 | `nextlevelbuilder/ui-ux-pro-max-skill` (GitHub) | AI 기반 디자인 인텔리전스 스킬. 제품 요구사항을 분석하여 디자인 시스템을 자동 생성 |

---

## 커스텀 스킬 (Custom Skills)

`skills/` 디렉토리에 정의된 로컬 스킬 목록입니다.

### 개발 프로세스 (4단계 워크플로우)

| 스킬 | 트리거 | 설명 |
|------|--------|------|
| `dev-prd` | `/dev-prd {기능명}` | PRD(제품 요구사항 문서) 작성. 사용자와 협업하여 기능 기획 |
| `dev-architecture` | `/dev-architecture {기능명}` | 아키텍처 설계. 기술 옵션 분석 및 트레이드오프 제시 |
| `dev-spec` | `/dev-spec {기능명}` | 상세 구현 스펙 작성. 인수 조건(AC)을 Given-When-Then 형식으로 정의 |
| `dev-testcase` | `/dev-testcase {기능명}` | 테스트 케이스 자동 도출. 스펙의 AC에서 TC를 생성 |
| `dev-process` | `/dev-process {기능명}` | 위 4단계를 순차 실행하는 오케스트레이터 |

### 문서/스펙 작성

| 스킬 | 트리거 | 설명 |
|------|--------|------|
| `write-app-spec` | `/write-app-spec` | 프론트엔드/풀스택 앱의 코드베이스를 분석하여 화면, 라우팅, 핵심 로직, 데이터 모델을 문서화한 SPEC.md 생성 |
| `write-nestjs-spec` | `/write-nestjs-spec {모듈명}` | NestJS 백엔드 모듈 API 스펙 문서 생성 |

### 브라우저 테스트/검증

| 스킬 | 트리거 | 설명 |
|------|--------|------|
| `validate-ui` | UI 변경 후 검증 요청 시 | Chrome DevTools MCP를 사용한 4계층 검증(A11y Snapshot, Screenshot, DOM Query, Runtime Logs) |
| `measure-rerender` | 리렌더링 성능 측정 요청 시 | React 컴포넌트 리렌더링 횟수 측정 및 비교 분석 |
| `mobile-view-debugger` | 모바일 뷰 문제 진단 요청 시 | 모바일 에뮬레이션 + 자동 진단(오버플로우, 터치 타겟 등) |

---

## 훅 (Hooks)

| 이벤트 | 실행 명령 | 비동기 | 설명 |
|--------|-----------|--------|------|
| `ConfigChange` | `bash "$HOME/claude-dotfiles/scripts/dotfiles-sync.sh"` | ✅ | 설정 변경 시 자동으로 git commit + push 동기화 |

---

## 권한 (Permissions)

### 허용 (Allow)

| 도구/명령 | 설명 |
|-----------|------|
| `Read`, `Edit`, `Write`, `Glob`, `Grep` | 기본 파일 조작 도구 |
| `Bash(find/ls/cat/cd/npm/pnpm/grep/xargs grep)` | 셸 명령 (제한적) |
| `mcp__plugin_playwright_*` | Playwright 브라우저 도구 전체 |
| `mcp__plugin_chrome-devtools-mcp_chrome-devtools*` | Chrome DevTools MCP 도구 전체 |

### 거부 (Deny)

| 패턴 | 설명 |
|------|------|
| `Write(./.env)` | 환경 변수 파일 쓰기 금지 |
| `Write(./node_modules/**)` | node_modules 쓰기 금지 |
| `Bash(* deploy/publish *)` | 배포/퍼블리시 명령 금지 |
| `Bash(git push/pull *)` | git push/pull 자동 실행 금지 |

---

## 글로벌 인스트럭션 (CLAUDE.md)

```
- 스킬 생성 시 `--path`는 항상 `~/.claude/skills`를 사용할 것
```
