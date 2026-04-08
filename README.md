# Claude Code Dotfiles

여러 환경에서 동일한 Claude Code 전역 설정을 유지하기 위한 dotfiles 레포.

## 관리 대상

| 파일 | 용도 |
|------|------|
| `settings.json` | 전역 permissions, 플러그인 활성화, 모델 등 |
| `skills/` | 커스텀 스킬 디렉토리 |
| `plugins/installed_plugins.json` | 설치된 플러그인 목록 |

## 새 환경에서 설치

```bash
git clone https://github.com/<user>/claude-dotfiles.git ~/claude-dotfiles
cd ~/claude-dotfiles

# Linux / macOS
./install.sh

# Windows
.\install.bat
```

## install 스크립트 동작

`install.sh` (Linux/macOS) 와 `install.ps1` (Windows) 는 다음을 수행합니다.

1. **심볼릭 링크 생성** — `settings.json`, `plugins/installed_plugins.json`, `skills/` 디렉토리를 `~/.claude/` 아래에 심볼릭 링크로 연결합니다.
2. **기존 파일 백업** — 링크 대상 경로에 이미 파일이 있으면 `.bak` 확장자를 붙여 백업한 뒤 링크를 생성합니다. 이미 링크된 경우는 건너뜁니다.
3. **`dotclaude` alias 등록** — 셸 프로필(`~/.zshrc`, `~/.bashrc`, 또는 PowerShell `$PROFILE`)에 `dotclaude` alias/function을 자동으로 추가합니다. 이미 등록되어 있으면 경로만 갱신합니다.

설치 후 셸을 재시작하면 `dotclaude` 명령어로 dotfiles 레포를 관리할 수 있습니다.

```bash
dotclaude status
dotclaude add -A
dotclaude commit -m "update settings"
dotclaude push
dotclaude pull
```
