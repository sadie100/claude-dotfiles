# scripts/

설치·동기화·셸 통합에 쓰이는 스크립트 모음. 동일 역할의 스크립트는 OS별 변종까지 같은 폴더에 둠.

| 폴더 | 역할 |
|------|------|
| [`bootstrap/`](bootstrap/README.md) | 새 환경에서 원라이너로 레포 clone + install 실행 |
| [`install/`](install/README.md) | `~/.claude` 디렉토리에 symlink 생성, 셸 프로필 등록 |
| [`dotclaude-func/`](dotclaude-func/README.md) | 셸에 `dotclaude` 함수 등록 (sync, open, settings, git 패스스루) |
| [`dotfiles-sync/`](dotfiles-sync/README.md) | 변경분 자동 commit + push (`ConfigChange` 훅 + `dotclaude sync`) |

## 호출 관계

```
bootstrap/*  ──▶  install/*  ──▶  dotclaude-func/*  (셸 프로필에 source)
                      │
                      └─▶  dotfiles-sync/*   (ConfigChange 훅에서 호출)
```
