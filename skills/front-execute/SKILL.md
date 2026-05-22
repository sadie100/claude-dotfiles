---
name: ship
description: 구현 완료 후 코드 리뷰 → UI 검증 파이프라인을 실행한다. 작업이 끝났다고 판단되는 시점에 사용. 트리거 - "ship", "마무리", "리뷰하고 검증해줘", "내보낼 준비", "PR 준비", "구현 끝났어 검증" 등. 인자로 기능명/변경 요약을 받을 수 있다.
---

# /ship — 구현 후 검증 파이프라인

구현 → **코드 리뷰** → **UI 검증** → **요약** 을 순차적으로 돌린다. 사람이 control 에 남고, 각 페이즈 실패 시 사용자에게 의사결정을 요청한다.

## 전제

- `code-reviewer` 서브에이전트와 `ui-validator` 서브에이전트가 사용 가능해야 한다 (`~/.claude/agents/` 또는 프로젝트 `.claude/agents/`)
- 산출물은 `.claude/plans/` 아래에 저장 (없으면 생성)

## 페이즈

### Phase 1: 변경 요약 + 기본 검증

1. `git status`, `git diff <base>...HEAD --stat` 로 변경 파악
2. 변경 의도 1~2문장으로 요약 출력 (사용자에게 보여줌)
3. 프로젝트의 빌드/타입체크/유닛테스트 명령 실행
   - `package.json` scripts (test, typecheck, lint, build)
   - `Makefile`, `pyproject.toml`, `Cargo.toml` 등
   - 정확한 명령은 프로젝트 README/CLAUDE.md 에서 추론
4. 실패 시 **멈추고** 사용자에게 보고

> 변경이 매우 작거나(1~2 라인) 명백한 수정이면, "Phase 2/3 스킵하고 그냥 커밋할까요?" 한 번 물어볼 것.

### Phase 2: Code Review

Task 도구로 `code-reviewer` 서브에이전트 호출.

- 프롬프트에 base branch 와 변경 요약 전달
- 결과(전문)를 `.claude/plans/review-summary.md` 에 저장
- 반환된 `STATUS` 라인에 따라 분기:

| STATUS | 동작 |
|---|---|
| `PASS` | Phase 3 진행 |
| `ADVISORY` | Minor 이슈를 사용자에게 보여주고 "진행할까요?" 묻기 |
| `NEEDS_FIX` | **멈춤**. Critical/Major 이슈 출력 후 "지금 수정할까요?" 묻기. 사용자가 "응" 하면 직접 수정하고 **Phase 1 부터 재시작** |

### Phase 3: UI Validation

Task 도구로 `ui-validator` 서브에이전트 호출.

- 결과 전문을 `.claude/plans/ui-validation.md` 에 저장
- 스크린샷 증거는 `.claude/plans/ui-evidence/` 에 누적
- `STATUS` 에 따라:

| STATUS | 동작 |
|---|---|
| `PASS` | Phase 4 진행 |
| `N/A` (UI 변경 아님) | Phase 4 진행 |
| `FAIL` | **멈춤**. 실패 시나리오 출력 후 수정/무시/종료 중 선택 받기 |

### Phase 4: 최종 요약

```markdown
# /ship 결과

## ✅ 통과한 단계
- Phase 1: 빌드/테스트 — ...
- Phase 2: 코드 리뷰 — STATUS, 발견 N건
- Phase 3: UI 검증 — STATUS, 시나리오 N개

## 📎 산출물
- 리뷰: .claude/plans/review-summary.md
- UI 검증: .claude/plans/ui-validation.md
- 스크린샷: .claude/plans/ui-evidence/

## 다음 액션 제안
- (커밋 / PR 생성 / 추가 수정 중 적절한 것)
```

## 운영 규칙

- **사람이 control 에 있다.** 페이즈 사이 자동 진행은 OK, 그러나 **실패 시** 반드시 사용자 결정을 받는다.
- 서브에이전트 호출 시 description 에 phase 번호와 base branch 를 명시한다.
- 변경분이 백엔드 only 면 Phase 3 는 ui-validator 가 자동으로 `N/A` 반환하니 그대로 통과시킨다.
- `.claude/plans/` 가 없으면 생성한다 (`mkdir -p`).
- 사용자가 인자로 추가 컨텍스트를 줬으면 ($ARGUMENTS 같은 변경 요약), Phase 1 의 변경 의도 요약에 반영한다.

## 호출 예시

- "구현 끝났어 ship 해줘"
- "ship 로그인 페이지 리팩토링"
- "마무리 검증 돌려줘"
- "리뷰랑 화면검증 돌려"
