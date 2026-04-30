# Claude Code Dotfiles

여러 환경에서 동일한 Claude Code 전역 설정을 유지하기 위한 dotfiles 레포.

## 관리 대상

| 파일 | 용도 | 설치 방식 | 자동 동기화 |
|------|------|-----------|-------------|
| `settings.json` | 전역 permissions, 모델, 플러그인 활성화 등 | JSON 머지 + symlink | O |
| `skills/` | 커스텀 스킬 디렉토리 | 스킬 폴더를 symlink | O |
| `CLAUDE.md` | 전역 지시사항 | symlink | O |

## 새 환경에서 설치 (원라이너)

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/scripts/bootstrap.sh | bash

# Windows (PowerShell, 관리자 권한 자동 요청)
irm https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/scripts/bootstrap.ps1 | iex
```

기본 클론 위치는 `~/claude-dotfiles`. 변경하려면:

```bash
DOTFILES_DIR=~/my-claude curl -fsSL https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/scripts/bootstrap.sh | bash
```

### 수동 설치

```bash
git clone https://github.com/sadie100/claude-dotfiles.git ~/claude-dotfiles
cd ~/claude-dotfiles

# Linux / macOS
./scripts/install.sh

# Windows (관리자 권한 자동 요청)
.\scripts\install.bat
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

### 3. CLAUDE.md — symlink
기존 `~/.claude/CLAUDE.md`가 있으면 `.bak`으로 백업한 뒤, 이 레포의 `CLAUDE.md`로 symlink를 생성합니다. 이미 링크된 경우 건너뜀.

직접 `~/.claude/CLAUDE.md`를 편집하면 레포의 파일이 수정되므로, 자동 동기화로 반영됩니다.

### 4. `DOTCLAUDE_DIR` 환경변수 등록
이 레포의 절대 경로를 `DOTCLAUDE_DIR` 환경변수로 등록합니다. 자동 동기화 훅 등에서 레포 위치를 참조할 때 사용됩니다.

- **Linux/macOS**: 셸 프로필(`~/.zshrc`, `~/.bashrc`)에 `export DOTCLAUDE_DIR=...` 추가
- **Windows**: `[Environment]::SetEnvironmentVariable`로 **사용자 환경변수에 영구 등록** + PowerShell 프로필에도 `$env:DOTCLAUDE_DIR` 설정

> Windows에서 시스템 환경변수로 등록하는 이유: PowerShell 프로필 변수는 해당 세션에서만 유효하지만, Claude Code 훅은 bash(Git Bash)로 실행되어 PowerShell 프로필을 읽지 못합니다. 시스템 환경변수는 모든 셸에서 접근 가능합니다.

### 5. dotclaude 함수 등록
셸 프로필(`~/.zshrc`, `~/.bashrc`, 또는 PowerShell `$PROFILE`)에 `dotclaude` 함수를 등록합니다.

함수 본문은 레포의 `scripts/dotclaude-func.sh` (Bash) / `scripts/dotclaude-func.ps1` (PowerShell)에 있고, 프로필에는 환경변수 설정 + source 두 줄만 추가됩니다. 따라서 `git pull`만 하면 모든 머신에서 함수가 즉시 업데이트됩니다.

```bash
dotclaude --help      # 지원하는 모든 커맨드 보기
dotclaude sync        # add -A + commit + push (한방)
dotclaude open        # dotfiles 디렉토리 열기
dotclaude settings    # settings.json 편집 (--vim, --code 등)
dotclaude status      # git status (git 명령 패스스루)
dotclaude log         # git log
dotclaude pull        # git pull
```

## 동기화

### 자동 동기화

`settings.json`에 `ConfigChange` 훅이 설정되어 있어, **settings.json** 또는 **skills/** 변경 시 자동으로 commit + push 합니다.

- 변경 감지 → `git add -A` → `git commit` → `git push`
- 오프라인이면 다음 sync 때 push
- push 충돌 시 `pull --rebase` 후 재시도

### 수동 동기화

자동 동기화 훅이 감지하지 못하는 변경이 있을 경우 `dotclaude sync`로 동기화하세요:

```bash
dotclaude sync
```
