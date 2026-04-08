# Claude Code Dotfiles

여러 환경에서 동일한 Claude Code 전역 설정을 유지하기 위한 dotfiles 레포.

## 관리 대상

| 파일 | 용도 | 설치 방식 |
|------|------|-----------|
| `settings.json` | 전역 permissions, 모델 등 | symlink |
| `skills/` | 커스텀 스킬 디렉토리 | 스킬 폴더를 symlink |
| `plugins/installed_plugins.json` | 설치된 플러그인 목록 | JSON 머지 |
| `CLAUDE.md` | 전역 지시사항 | 마커 블록으로 머지 |

## 새 환경에서 설치

```bash
git clone https://github.com/<user>/claude-dotfiles.git ~/claude-dotfiles
cd ~/claude-dotfiles

# Linux / macOS
./install.sh

# Windows (관리자 권한 자동 요청)
.\install.bat
```

## install 스크립트 동작

`install.sh` (Linux/macOS) 와 `install.ps1` (Windows) 는 다음을 수행합니다.

### 1. settings.json — symlink
기존 파일이 있으면 `.bak`으로 백업 후 symlink 생성. 이미 링크된 경우 건너뜀.

### 2. skills — 흡수 + 디렉토리 symlink
- **흡수**: 기존 `~/.claude/skills/`에 있는 스킬을 이 레포의 `skills/`로 복사
- **연결**: `~/.claude/skills/` 디렉토리 자체를 이 레포의 `skills/`로 symlink

기존 스킬이 레포에 이미 있으면 로컬 것을 `.bak`으로 백업.

디렉토리 통째로 연결되므로, 이후 새 스킬을 만들면 자동으로 레포에 반영됩니다.

### 3. CLAUDE.md — 마커 블록 머지
기존 `~/.claude/CLAUDE.md` 내용은 유지하고, 레포의 내용을 마커 블록으로 추가합니다.

```markdown
# 사용자의 기존 내용은 그대로

# >>> claude-dotfiles >>>
(이 레포의 CLAUDE.md 내용)
# <<< claude-dotfiles <<<
```

재실행 시 마커 블록 안의 내용만 업데이트. 마커 밖의 내용은 건드리지 않습니다.

### 4. installed_plugins.json — JSON 머지
기존 플러그인 목록에 레포의 플러그인을 추가합니다. 이미 존재하는 플러그인은 기존 것을 유지.

### 5. dotclaude alias 등록
셸 프로필(`~/.zshrc`, `~/.bashrc`, 또는 PowerShell `$PROFILE`)에 `dotclaude` alias/function을 등록합니다.

```bash
dotclaude status
dotclaude add -A
dotclaude commit -m "update settings"
dotclaude push
dotclaude pull
```
