# scripts/

설치·동기화·셸 통합에 쓰이는 스크립트 모음. 동일 역할의 스크립트는 OS별 변종까지 같은 폴더에 둠.

| 폴더 | 역할 |
|------|------|
| [`bootstrap/`](bootstrap/README.md) | 새 환경에서 원라이너로 레포 clone + install 실행 |
| [`install/`](install/README.md) | `~/.claude` 디렉토리에 symlink 생성, 셸 프로필 등록 |
| [`dotclaude-func/`](dotclaude-func/README.md) | 셸에 `dotclaude` 함수 등록 (sync, open, settings, git 패스스루) |
| [`dotfiles-sync/`](dotfiles-sync/README.md) | 변경분 자동 commit + push (`harness-sync` 마지막 단계에서 체이닝 호출) |
| [`harness-sync/`](harness-sync/README.md) | `settings.json` + 플러그인 캐시 → `HARNESS.md` 자동 섹션 갱신 (`ConfigChange` 훅 진입점) |
| `mcp-sync/` | user-scope MCP 서버를 `mcp-servers.json` ↔ `~/.claude.json` 사이에서 pull/sync (secret 마스킹) |
| `hooks/` | `settings.json`이 직접 참조하는 훅 스크립트 (예: `notify.mjs` — 크로스 플랫폼 데스크탑 알림) |

## 호출 관계

```
bootstrap/*  ──▶  install/*  ──▶  dotclaude-func/*  (셸 프로필에 source)
                                         │
                                         ▼
                                   harness-sync/*   (ConfigChange 훅 + dotclaude sync 진입점)
                                         │
                                         └─▶  dotfiles-sync/*   (항상 마지막에 체이닝)
```

`mcp-sync/`는 `dotclaude mcp pull|sync` 서브커맨드, `hooks/`는 `settings.json`의 훅 정의에서 각각 직접 호출된다.
