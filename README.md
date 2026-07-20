# Claude Code Dotfiles

여러 환경에서 동일한 Claude Code 전역 설정을 유지하기 위한 개인 하네스 레포

## 생성 이유

Claude Code는 머신마다 `~/.claude/` 아래에 settings, skills, CLAUDE.md를 따로 들고 있어서 머신마다 설정을 따로 관리해야 하는 불편함이 있습니다.
이 레포는 여러 머신에서 설정을 동기화하기 위해 구상되었으며, 개인 하네스 설정을 백업함과 동시에 Git과 symlink를 활용해 각 머신에서 설정을 자동 동기화합니다.

이 레포가 해주는 일은 다음과 같습니다.

- `settings.json`, `skills/`, `CLAUDE.md` 등 클로드 코드 설정을 git 레포에 SSOT로 관리하고, symlink로 ~/.claude/ 아래에 연결해서 여러 머신에서 동일한 설정 유지
- 머신 고유 상태 혹은 민감정보(MCP 토큰, OAuth 세션 등)는 stripping을 통해 제외
- `settings.json`이나 `skills/`를 수정하면 훅이 자동으로 commit + push를 호출해 변경사항을 레포에 반영
- 하네스 구성(스킬, 플러그인 등)이 바뀌면 [HARNESS.md](./HARNESS.md)를 자동으로 업데이트하여 추가된 툴에 대한 설명을 기록
- 새 머신에 원라이너 한 줄로 세팅 동기화 가능

## 관리 대상

| 파일 | 용도 | 설치 방식 | 자동 동기화 |
|------|------|-----------|-------------|
| `settings.json` | 전역 permissions, 모델, 플러그인 활성화 등 | JSON 머지 + symlink | O |
| `skills/` | 커스텀 스킬 디렉토리 | 스킬 폴더를 symlink | O |
| `agents/` | 커스텀 서브에이전트 (react-code-reviewer, ui-validator 등) | 디렉토리 symlink | O |
| `CLAUDE.md` | 전역 지시사항 | symlink | O |
| `mcp-servers.json` | user-scope MCP 서버 (`~/.claude.json`의 `mcpServers` 키) | JSON 머지 (수동 / `dotclaude pull` 시 자동) | X |

### `skills/.ignore/` — 로컬/회사 전용 스킬

`skills/.ignore/` 아래에 둔 스킬은 `.gitignore`로 제외되어 git에 추적되지 않고, [HARNESS.md](./HARNESS.md) 자동 생성에도 포함되지 않습니다. 회사 도메인이나 머신 고유 설정에 종속된 스킬처럼 레포에 올리고 싶지 않은 스킬을 둘 때 사용하세요.

- Claude Code는 `skills/` 바로 아래 1단계 폴더의 SKILL.md만 로드하므로, `scripts/local-skills-link/local-skills-link.sh`가 최상위 심링크(`skills/foo -> .ignore/foo`)를 만들어 노출합니다. 심링크는 `.git/info/exclude`에 자동 등록되어 git에 노출되지 않습니다
- 이 스크립트는 `ConfigChange` 훅으로 자동 실행됩니다. 스킬을 추가했는데 심링크가 안 생겼다면 수동으로 한 번 실행하세요
- 기기 간 동기화되지 않으므로 필요한 각 기기에서 직접 채워야 합니다

## 설치 방법

### 새 환경에서 설치 (원라이너)

> [!CAUTION]
> 아래 원라이너 스크립트 실행 시 실행된 컴퓨터 환경의 전역 클로드 설정값이 해당 하네스로 덮어씌워집니다.

```bash
# 레포를 ~/claude-dotfiles에 clone (이미 있으면 pull) 후 install 스크립트 실행

# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/scripts/bootstrap/bootstrap.sh | bash

# Windows (PowerShell, 관리자 권한 자동 요청)
irm https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/scripts/bootstrap/bootstrap.ps1 | iex
```

기본 클론 위치는 `~/claude-dotfiles`. 변경하려면 다음과 같이 DOTFILES_DIR 수동 설정:

```bash
DOTFILES_DIR=~/my-claude curl -fsSL https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/scripts/bootstrap/bootstrap.sh | bash
```

### 수동 설치

```bash
git clone https://github.com/sadie100/claude-dotfiles.git ~/claude-dotfiles
cd ~/claude-dotfiles

# Linux / macOS
./scripts/install/install.sh

# Windows (관리자 권한 자동 요청)
.\scripts\install\install.bat
```

## 동작 원리

### install 스크립트 동작

`install.sh` (Linux/macOS) 와 `install.ps1` (Windows) 는 다음을 수행합니다.

#### 1. settings.json — JSON 머지 + symlink
기존 `~/.claude/settings.json`이 있으면 dotfiles 버전과 **deep merge** 후 symlink 생성. 이미 링크된 경우 건너뜀.

- **dotfiles 키 우선** — 충돌 시 dotfiles 값 유지
- **사용자 고유 키 보존** — dotfiles에 없는 키는 그대로 추가
- **배열 합집합** — `permissions.allow` 등 배열은 중복 없이 합침
- 머지 결과는 dotfiles `settings.json`에 반영되고, 원본은 `.bak`으로 백업

#### 2. skills — 흡수 + 디렉토리 symlink
- **흡수**: 기존 `~/.claude/skills/`에 있는 스킬을 이 레포의 `skills/`로 복사
- **연결**: `~/.claude/skills/` 디렉토리 자체를 이 레포의 `skills/`로 symlink

기존 스킬이 레포에 이미 있으면 로컬 것을 `.bak`으로 백업.

디렉토리 통째로 연결되므로, 이후 새 스킬을 만들면 자동으로 레포에 반영됩니다.

#### 3. CLAUDE.md — symlink
기존 `~/.claude/CLAUDE.md`가 있으면 `.bak`으로 백업한 뒤, 이 레포의 `CLAUDE.md`로 symlink를 생성합니다. 이미 링크된 경우 건너뜀.

직접 `~/.claude/CLAUDE.md`를 편집하면 레포의 파일이 수정되므로, 자동 동기화로 반영됩니다.

#### 4. mcp-servers.json — `~/.claude.json` 머지
기존 `~/.claude.json`의 최상위 `mcpServers` (user-scope MCP 서버) 를 이 레포의 `mcp-servers.json`과 머지. 첫 install이면 머신 서버를 레포로 흡수하고, 이후엔 레포의 mcp 서버를 `~/.claude.json`에 머지합니다.

- **시크릿 stripping** — 레포 저장 시 `env`, `headers`, `oauth` value는 `{}`로 비워서 git에 토큰이 안 올라감
- **머신 토큰 보존** — 머지 시 머신에 이미 채워진 토큰은 덮어쓰지 않음
- 새 머신에서는 서버 등록은 자동, 토큰은 `claude mcp add` 또는 직접 `~/.claude.json` 편집으로 채워주세요

`~/.claude.json`은 OAuth 세션·캐시 등 머신 고유 상태도 들고 있어 symlink가 불가능하고 Claude Code가 세션 중 계속 rewrite하므로 자동 동기화는 어렵다고 판단, mcpServers 키만 떼서 수동 방식으로 동기화합니다.

#### 5. `DOTCLAUDE_DIR` 환경변수 등록
이 레포의 절대 경로를 `DOTCLAUDE_DIR` 환경변수로 등록합니다. 자동 동기화 훅 등에서 레포 위치를 참조할 때 사용됩니다.

- **Linux/macOS**: 셸 프로필(`~/.zshrc`, `~/.bashrc`)에 `export DOTCLAUDE_DIR=...` 추가
- **Windows**: `[Environment]::SetEnvironmentVariable`로 **사용자 환경변수에 영구 등록** + PowerShell 프로필에도 `$env:DOTCLAUDE_DIR` 설정

> Windows에서 사용자 환경변수로 등록하는 이유: PowerShell 프로필 변수는 해당 세션에서만 유효하지만, Claude Code 훅은 bash(Git Bash)로 실행되어 PowerShell 프로필을 읽지 못합니다. 사용자 환경변수로 등록하면 PowerShell, bash 등 모든 셸에서 접근 가능합니다.

#### 6. dotclaude 함수 등록
셸 프로필(`~/.zshrc`, `~/.bashrc`, 또는 PowerShell `$PROFILE`)에 `dotclaude` 함수를 등록합니다.

함수 본문은 레포의 `scripts/dotclaude-func/dotclaude-func.sh` (Bash) / `scripts/dotclaude-func/dotclaude-func.ps1` (PowerShell)에 있고, 프로필에는 환경변수 설정 + source 두 줄만 추가됩니다. 따라서 `git pull`만 하면 모든 머신에서 함수가 즉시 업데이트됩니다.

```bash
dotclaude --help      # 지원하는 모든 커맨드 보기
dotclaude sync        # add -A + commit + push (한방)
dotclaude pull        # git pull + mcp-servers.json 자동 머지 (양방향 흐름의 수신 쪽)
dotclaude mcp-sync    # 머신 -> repo: ~/.claude.json의 mcpServers를 시크릿 stripped로 repo에 저장
dotclaude mcp-pull    # repo -> 머신: repo의 mcp-servers.json을 ~/.claude.json에 머지 (토큰 보존)
dotclaude open        # dotfiles 디렉토리 열기
dotclaude settings    # settings.json 편집 (--vim, --code 등)
dotclaude unlink      # 이 머신을 레포에서 분리 (symlink -> 실제 복사본, 레포/원격은 보존)
dotclaude status      # git status (git 명령 패스스루)
dotclaude log         # git log
```

### unlink 스크립트 동작 (레포에서 분리)

`install`의 역방향. `dotclaude unlink` (또는 `scripts/unlink/unlink.{sh,ps1}`)는 이 머신의 `~/.claude`를 레포에서 떼어내 독립형으로 만듭니다. 레포 폴더와 GitHub 원격은 건드리지 않으므로, 나중에 `install`을 재실행하면 그대로 재연결됩니다.

1. **symlink → 실제 복사본** — `settings.json`·`CLAUDE.md`·`skills/`·`agents/`가 symlink면 레포 내용을 복사한 실제 파일/디렉토리로 교체 (이미 실제 파일이면 건너뜀)
2. **레포 의존 훅 제거** — `settings.json`에서 `DOTCLAUDE_DIR`를 참조하는 훅(`ConfigChange`→harness-sync, `Notification`→notify.mjs)만 떼어냄. 레포 비의존 훅과 `permissions`·`enabledPlugins` 등은 유지
3. **`DOTCLAUDE_DIR` 환경변수 + `dotclaude` 함수 제거** — 사용자 환경변수와 셸 프로필의 `dotclaude` 블록 삭제

레포 폴더 자체를 그냥 지우면 symlink가 끊겨 전역 설정이 사라지고 사라진 스크립트를 가리키는 훅이 에러를 내지만, `unlink`로 먼저 분리하면 전역 설정을 온전한 실제 파일로 남긴 채 안전하게 정리할 수 있습니다.

### 동기화

#### 자동 동기화

`settings.json`에 `ConfigChange` 훅이 설정되어 있어, **settings.json** 또는 **skills/** 변경 시 자동으로 commit + push 합니다.

- 변경 감지 → `git add -A` → `git commit` → `git push`
- 오프라인이면 다음 sync 때 push
- push 충돌 시 `pull --rebase` 후 재시도

#### 수동 동기화

자동 동기화 훅이 감지하지 못하는 변경이 있을 경우 `dotclaude sync`로 동기화하세요:

```bash
dotclaude sync
```

MCP 서버는 자동 동기화 대상이 아니므로 다음 명령으로 동기화합니다:

```bash
dotclaude mcp-sync    # 머신->레포 동기화. (claude mcp add 후)
dotclaude mcp-pull        # 레포->머신 동기화. (수동 git pull 후)
```
