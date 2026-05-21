# bootstrap

새 환경에서 원라이너로 dotfiles를 설치할 때 사용하는 진입 스크립트.

## 파일

| 파일 | 실행 환경 | 역할 |
|------|-----------|------|
| `bootstrap.sh` | Linux / macOS (bash) | git clone(또는 pull) → `install/install.sh` 실행 |
| `bootstrap.ps1` | Windows (PowerShell) | 관리자 권한 자동 요청 → git clone(또는 pull) → `install/install.ps1` 실행 |

## 동작

1. `git` 존재 확인 (없으면 종료)
2. `$DOTFILES_DIR` (기본값: `~/claude-dotfiles`)에 레포가 이미 있으면 `pull --rebase`, 없으면 `clone`
3. `install/` 아래의 플랫폼별 설치 스크립트 실행

## 환경변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `REPO_URL` | `https://github.com/sadie100/claude-dotfiles.git` | clone할 레포 URL |
| `DOTFILES_DIR` | `~/claude-dotfiles` | clone 대상 경로 |

## 실행 (루트 README 참고)

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/scripts/bootstrap/bootstrap.sh | bash

# Windows
irm https://raw.githubusercontent.com/sadie100/claude-dotfiles/master/scripts/bootstrap/bootstrap.ps1 | iex
```
