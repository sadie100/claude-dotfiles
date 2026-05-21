# harness-sync

`HARNESS.md`의 자동 관리 섹션(플러그인 / 스킬 / 훅)을 `settings.json` + Claude Code 플러그인 캐시에서 추출한 데이터로 갱신하는 스크립트.

데이터 수집은 결정적 Node 코드, 마크다운 렌더링은 `claude -p`(headless LLM) 가 담당하는 하이브리드 구조.

## 파일

| 파일 | 역할 |
|------|------|
| `harness-sync.mjs` | Node.js. fingerprint 비교 → 데이터 수집 → `claude -p` 호출 → HARNESS.md 갱신 |

## 트리거

`settings.json`의 `ConfigChange` 훅에서 호출됨 (dotfiles-sync 앞단, 동기):

```jsonc
"hooks": {
  "ConfigChange": [{
    "hooks": [
      {
        "type": "command",
        "command": "node \"$DOTCLAUDE_DIR/scripts/harness-sync/harness-sync.mjs\"",
        "async": false
      },
      {
        "type": "command",
        "command": "node \"$DOTCLAUDE_DIR/scripts/dotfiles-sync/dotfiles-sync.mjs\"",
        "async": true
      }
    ]
  }]
}
```

`custom-skill-creator` 스킬의 워크플로 마지막에도 명시 호출 (로컬 스킬 변경은 `settings.json`을 안 건드려 ConfigChange가 발화하지 않으므로). fingerprint에 로컬 스킬 목록이 포함되어 있으므로 `--force` 없이도 변경분이 자동 감지됨.

## 수동 실행

```bash
# fingerprint가 바뀌었을 때만 갱신
node scripts/harness-sync/harness-sync.mjs

# 무조건 갱신 (fingerprint 게이트 우회)
node scripts/harness-sync/harness-sync.mjs --force
```

`DOTCLAUDE_DIR`이 잡혀있으면 어디서든 호출 가능.

## 동작

1. **fingerprint 계산**: `sha256({enabledPlugins, hooks, localSkills})` (정렬된 키)
2. **fingerprint 비교**: `HARNESS.md` 최상단 `<!-- harness-sync-fingerprint: <hex> -->` 와 일치하면 즉시 exit (수십 ms, 비용 0). `--force`면 건너뜀
3. **데이터 수집** (`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`에서, 버전 디렉토리는 mtime 최신):
   - `.claude-plugin/plugin.json` — name / description / version
   - `skills/*/SKILL.md`, `.claude/skills/*/SKILL.md`, `src/skills/*/SKILL.md` frontmatter
   - `commands/*.md` frontmatter
   - `agents/*.md` frontmatter
   - `.mcp.json` — MCP 서버
   - `hooks/hooks.json` — 플러그인 자체 훅
   - 마켓플레이스 manifest (plugin.json 누락 시 fallback)
   - 레포 로컬 `skills/*/SKILL.md`
   - `settings.json.hooks`
4. **JSON 페이로드 직렬화** + 작성 가이드라인 prompt 구성
5. **`claude -p` spawn**:
   ```
   claude -p --permission-mode acceptEdits \
            --allowed-tools "Read Edit Write Glob Grep" \
            --model opus \
            --add-dir <repo>
   ```
   `claude`가 markered 구역(`<!-- AUTO:BEGIN <id> -->` … `<!-- AUTO:END <id> -->`)만 Edit
6. **sanity check**: 마커 4쌍 무결성 확인 → 깨졌으면 롤백
7. **fingerprint 주석 갱신** (claude가 빠뜨려도 스크립트가 안전망으로 덮어씀)

## 마커

`HARNESS.md`의 다음 구역만 LLM이 다시 씀. 그 외(인트로 등)는 절대 건드리지 않음.

- `<!-- AUTO:BEGIN plugins -->` … `<!-- AUTO:END plugins -->`
- `<!-- AUTO:BEGIN skills -->` … `<!-- AUTO:END skills -->`
- `<!-- AUTO:BEGIN hooks -->` … `<!-- AUTO:END hooks -->`

## 환경변수

| 변수 | 용도 | 기본값 |
|------|------|--------|
| `DOTCLAUDE_DIR` | 레포 루트 경로 | 스크립트 위치 기준 `../..` |

## 비용·지연

- fingerprint 일치 시: 수십 ms, LLM 호출 0
- 변경 시: Opus 호출 1회당 약 10–30초 / 수십 센트
- 발생 빈도: 플러그인 토글, 훅 변경, 스킬 추가 — 주당 몇 회 수준

## 엣지 케이스

- **`claude` CLI 미설치/PATH 누락**: spawn 실패 → stderr 메시지 후 silent exit. HARNESS.md 보존
- **`claude -p`가 마커를 깨뜨림**: 실행 후 마커 4쌍 sanity check, 실패 시 원본으로 롤백
- **fingerprint 주석이 없는 첫 실행**: 빈 hex로 간주 → 무조건 호출
- **여러 버전 디렉토리 공존**: mtime 최신 선택
- **권한 프롬프트**: `--permission-mode acceptEdits` + `--allowed-tools` 명시로 우회
