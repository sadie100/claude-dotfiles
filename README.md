# Claude Code Dotfiles

여러 환경에서 동일한 Claude Code 전역 설정을 유지하기 위한 dotfiles 레포.

## 관리 대상

| 파일 | 용도 | 설치 방식 | 자동 동기화 |
|------|------|-----------|-------------|
| `settings.json` | 전역 permissions, 모델, 플러그인 활성화 등 | JSON 머지 + symlink | O |
| `skills/` | 커스텀 스킬 디렉토리 | 스킬 폴더를 symlink | O |
| `CLAUDE.md` | 전역 지시사항 | 마커 블록으로 머지 | X (수동) |

## 새 환경에서 설치 (원라이너)

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/bootstrap.sh | bash

# Windows (PowerShell, 관리자 권한 자동 요청)
irm https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/bootstrap.ps1 | iex
```

기본 클론 위치는 `~/claude-dotfiles`. 변경하려면:

```bash
DOTFILES_DIR=~/my-claude curl -fsSL https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/bootstrap.sh | bash
```

### 수동 설치

```bash
git clone https://github.com/sadie100/claude-dotfiles.git ~/claude-dotfiles
cd ~/claude-dotfiles

# Linux / macOS
./install.sh

# Windows (관리자 권한 자동 요청)
.\install.bat
```

## install 스크립트 동작

`install.sh` (Linux/macOS) 와 `install.ps1` (Windows) 는 다음을 수행합니다.

### 1. settings.json — JSON 머지 + symlink
기존 `~/.claude/settings.json`이 있으면 dotfiles 버전과 **deep merge** 후 symlink 생성. 이미 링크된 경우 건너뜀.

- **dotfiles 키 우선** — 충돌 시 dotfiles 값 유지
- **사용자 고유 키 보존** — dotfiles에 없는 키는 그대로 추가
- **배열 합집합** — `permissions.allow` 등 배열은 중복 없이 합침
- 머지 결과는 dotfiles `settings.json`에 반영되고, 원본은 `.bak`으로 백업

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

### 4. dotclaude 함수 등록
셸 프로필(`~/.zshrc`, `~/.bashrc`, 또는 PowerShell `$PROFILE`)에 `dotclaude` 함수를 등록합니다. 자동 동기화 대상이 아닌 파일(CLAUDE.md)을 수동으로 동기화할 때 사용합니다.

```bash
dotclaude sync    # add -A + commit + push (한방)
dotclaude status  # git status
dotclaude log     # git log
dotclaude pull    # git pull
```

## 동기화

### 자동 동기화

`settings.json`에 `ConfigChange` 훅이 설정되어 있어, **settings.json** 또는 **skills/** 변경 시 자동으로 commit + push 합니다.

- 변경 감지 → `git add -A` → `git commit` → `git push`
- 오프라인이면 다음 sync 때 push
- push 충돌 시 `pull --rebase` 후 재시도

### 수동 동기화

**CLAUDE.md**는 symlink가 아닌 머지 방식이라 자동 동기화 대상이 아닙니다. 변경 시 `dotclaude sync`로 동기화하세요:

```bash
dotclaude sync
```
