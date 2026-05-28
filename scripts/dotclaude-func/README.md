# dotclaude-func

셸 프로필에서 source / dot-source되어 `dotclaude` 함수를 등록하는 스크립트.

## 파일

| 파일 | 실행 환경 | 등록 방식 |
|------|-----------|-----------|
| `dotclaude-func.sh` | bash / zsh | `~/.zshrc` 또는 `~/.bashrc`에서 `source` |
| `dotclaude-func.ps1` | PowerShell | `$PROFILE`에서 `.` (dot-source) |

`install` 단계에서 프로필에 환경변수 + source 두 줄만 추가하므로, 함수 본문을 수정해도 `git pull`만 하면 모든 머신에 반영됨.

## 제공 커맨드

```bash
dotclaude --help      # 도움말 출력
dotclaude sync        # git add -A + commit + push (한방 동기화)
dotclaude open        # dotfiles 디렉토리 파일 탐색기로 열기
dotclaude code        # dotfiles 디렉토리를 code 명령에 연결된 에디터로 열기 (VSCode/Cursor 등)
dotclaude settings    # settings.json 편집 (--vim, --vi, --nano, --code, --notepad)
dotclaude <git-cmd>   # 그 외 인자는 모두 git에 패스스루 (status, log, pull 등)
```

## 동작 메모

- `sync` 커맨드:
  - bash 버전: `dotfiles-sync/dotfiles-sync.sh` 호출
  - PowerShell 버전: 동일 로직을 inline으로 수행 (별도 호출 없음)
- 모든 git 명령은 `$DOTCLAUDE_DIR`을 작업 디렉토리로 사용하므로, 어느 경로에서 호출해도 dotfiles 레포에 대해 동작

## 사전 조건

`$DOTCLAUDE_DIR` (Windows: `$env:DOTCLAUDE_DIR`) 환경변수가 source 이전에 설정되어 있어야 함. install 스크립트가 이를 자동 처리.
