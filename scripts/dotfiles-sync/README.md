# dotfiles-sync

dotfiles 레포의 변경분을 자동으로 commit + push하는 동기화 스크립트.

## 파일

| 파일 | 실행 환경 | 역할 |
|------|-----------|------|
| `dotfiles-sync.mjs` | Node.js (크로스 플랫폼) | 플랫폼 감지 후 `.sh` 또는 `.ps1`로 라우팅하는 디스패처 |
| `dotfiles-sync.sh` | Linux / macOS (bash) | 동기화 본체 (lockdir 기반 동시성 제어) |
| `dotfiles-sync.ps1` | Windows (PowerShell) | 동기화 본체 (Named Mutex 기반 동시성 제어) |

## 트리거

`settings.json`의 `ConfigChange` 훅에서 호출됨:

```jsonc
"hooks": {
  "ConfigChange": [{
    "hooks": [{
      "type": "command",
      "command": "node \"$DOTCLAUDE_DIR/scripts/dotfiles-sync/dotfiles-sync.mjs\"",
      "async": true
    }]
  }]
}
```

`dotclaude sync` 커맨드(bash 버전)에서도 직접 호출.

## 동작

1. 동시 실행 방지: lockdir(bash) / Named Mutex(PowerShell) 획득 실패 시 즉시 종료
2. 변경분 검사: unstaged / staged / untracked가 모두 없으면 종료
3. `git add -A` → 변경 파일명을 메시지로 `git commit -m "sync: <files>"` (`--no-gpg-sign`)
4. `git push`, 충돌 시 `pull --rebase` 후 재시도, 그래도 실패하면 조용히 종료(오프라인 등)

모든 실패는 **silently fail** — 사용자 작업을 방해하지 않기 위함.

## 환경변수

| 변수 | 우선순위 | 기본값 |
|------|----------|--------|
| `DOTCLAUDE_DIR` | 1순위 | — |
| `DOTFILES_DIR` | 2순위 | `~/claude-dotfiles` |
