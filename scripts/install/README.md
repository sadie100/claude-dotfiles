# install

`~/.claude` 디렉토리에 dotfiles를 연결하고 셸 환경을 설정하는 설치 스크립트.

## 파일

| 파일 | 실행 환경 | 역할 |
|------|-----------|------|
| `install.sh` | Linux / macOS (bash) | symlink 생성 + 셸 프로필 등록 |
| `install.ps1` | Windows (PowerShell, 관리자) | symlink 생성 + 사용자 환경변수 등록 + PowerShell 프로필 등록 |
| `install.bat` | Windows (cmd) | `install.ps1` 호출용 얇은 래퍼 |

## 동작 순서

1. **`settings.json`** — 기존 사용자 설정과 dotfiles 버전을 deep merge한 뒤 symlink (충돌 시 dotfiles 우선, 배열은 합집합)
2. **`skills/`** — 기존 `~/.claude/skills/`의 스킬을 레포로 흡수한 뒤, 디렉토리 자체를 symlink
3. **`CLAUDE.md`** — symlink (기존 파일은 `.bak`으로 백업)
4. **`DOTCLAUDE_DIR` 환경변수** — 레포 절대경로를 등록 (Windows: 사용자 환경변수, Linux/macOS: 셸 프로필 `export`)
5. **`dotclaude` 함수** — 셸 프로필에 `dotclaude-func/dotclaude-func.{sh,ps1}` source 두 줄 추가
6. **변경사항 자동 sync** — merge 결과 등 변경분이 있으면 `dotfiles-sync`로 commit + push

## 수동 실행

```bash
# Linux / macOS
./scripts/install/install.sh

# Windows (관리자 권한 자동 요청)
.\scripts\install\install.bat
```

## 백업 정책

기존 파일을 덮어쓰지 않고 `.bak` 접미사로 보존:
- `~/.claude/settings.json` → `~/.claude/settings.json.bak`
- `~/.claude/CLAUDE.md` → `~/.claude/CLAUDE.md.bak`
- `~/.claude/skills/<name>/` (레포에 동일 이름 존재 시) → `<name>.bak/`
