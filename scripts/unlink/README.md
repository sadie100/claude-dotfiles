# unlink

`install`의 역방향. `~/.claude`를 dotfiles 레포에서 분리해 **독립형(standalone)**으로 만드는 스크립트. 레포 폴더와 GitHub 원격은 건드리지 않는다.

## 파일

| 파일 | 실행 환경 | 역할 |
|------|-----------|------|
| `unlink.mjs` | 공용 (node) | symlink → 실제 파일/디렉토리 복사 + `settings.json` 훅 스트립 |
| `unlink.sh` | Linux / macOS (bash) | 확인 → `unlink.mjs` 호출 → 셸 프로필에서 `dotclaude` 블록 제거 |
| `unlink.ps1` | Windows (PowerShell) | 확인 → `unlink.mjs` 호출 → 사용자 환경변수 + PowerShell 프로필 `dotclaude` 블록 제거 |

파일 작업을 `unlink.mjs` 하나로 모은 이유: Windows PowerShell 5.1의 `ConvertTo-Json`이 단일 요소 배열을 스칼라로 펼쳐 `hooks` 구조를 깨뜨리기 때문. node는 이미 이 레포의 하드 의존성이라 안전하다.

## 동작 순서

확인 프롬프트(`Detach this machine from dotfiles? [y/N]`) 후:

1. **symlink → 실제 복사본** — `settings.json` · `CLAUDE.md` · `skills/` · `agents/`가 symlink면 레포 내용을 복사한 실제 파일/디렉토리로 교체. 이미 실제 파일이거나 없으면 `[skip]`.
2. **`settings.json` 훅 스트립** — `command`에 `DOTCLAUDE_DIR`를 참조하는 훅(ConfigChange→harness-sync, Notification→notify.mjs)만 제거. 레포 비의존 훅(PostToolUse prettier 등)과 `permissions`·`model`·`enabledPlugins`는 유지.
3. **`DOTCLAUDE_DIR` 환경변수 제거** — Windows: 사용자 환경변수 삭제. Linux/macOS: 프로필 `export` 라인이 `dotclaude` 블록에 포함되어 4번에서 함께 제거.
4. **`dotclaude` 함수 제거** — 셸 프로필의 `# dotclaude-start` ~ `# dotclaude-end` 블록 삭제.

## 수동 실행

```bash
# Linux / macOS
./scripts/unlink/unlink.sh

# Windows
.\scripts\unlink\unlink.ps1
```

또는 `dotclaude unlink`.

## 특징

- **레포·원격 보존** — `~/.claude`만 분리하고 레포 폴더와 GitHub은 그대로 둔다. 나중에 `install`을 재실행하면 그대로 재연결된다.
- **멱등** — 두 번 실행해도 두 번째는 전부 `[skip]`이며 에러가 없다.
- **반영 시점** — 환경변수·함수 제거는 새 셸을 열어야 적용된다.
