---
name: deploy-egnis-vibe
description: 현재 프로젝트 폴더를 Egnis Vibe(vibe.egnis.net)에 배포해 사내 URL을 발급받습니다. 사용법 — /deploy-egnis-vibe 원하는주소 (예. /deploy-egnis-vibe sales-dash → sales-dash.egnis.net 발급, 주소를 생략하면 물어봅니다). 사용자가 명시적으로 요청할 때만 실행하고, 스스로 판단해 배포하지 않습니다.
metadata:
  short-description: Egnis Vibe(vibe.egnis.net)에 현재 폴더 배포
---

<!-- Claude/Codex 공용 SKILL.md. Claude 전용 frontmatter 키(disable-model-invocation, allowed-tools)는
     Codex validator가 거부하므로 넣지 않는다. 자동 실행 방지는 본문 "안전 규칙"으로 강제한다. -->

# Egnis Vibe 배포

현재 폴더를 zip으로 묶어 Vibe 플랫폼에 업로드하면, 웹 UI와 동일한 파이프라인을 거쳐 사내 URL을 발급한다:
**검증 → 격리 컨테이너 빌드 → Cloudflare 배포 → `<슬러그>.egnis.net` 발급 + 사내 인증 게이트 자동 적용 + 허브 목록 등록.**

## 사용법

```
/deploy-egnis-vibe <슬러그>        # 예: /deploy-egnis-vibe sales-dashboard
```

- `<슬러그>` = 서브도메인(영문 소문자·숫자·하이픈). 생략하면 사용자에게 물어본다.
- **제목은 필수** — 사용자에게 한 줄로 물어본다(한글 가능, 허브 목록에 표시됨). 설명·태그·사용법은 선택이며 있으면 함께 보낸다.

---

# 배포 절차

순서대로 진행하고, 각 단계가 실패하면 즉시 중단한 뒤 한국어로 원인을 설명한다.

## 0단계 — 스킬 자기 갱신 (매 실행 시)

이 스킬 문서는 서버 원본이 수시로 개선된다. 배포를 시작하기 전에 최신본인지 확인하고, 다르면 스스로 덮어쓴 뒤 새 내용 기준으로 진행한다.

- `SKILL_PATH` = 지금 읽고 있는 이 SKILL.md 파일의 실제 경로(예: `~/.claude/skills/deploy-egnis-vibe/SKILL.md` 또는 프로젝트의 `.claude/skills/deploy-egnis-vibe/SKILL.md`).

```bash
curl -fsS https://vibe.egnis.net/skills/deploy-egnis-vibe/SKILL.md -o /tmp/vibe-skill-latest.md 2>/dev/null \
  && ! diff -q /tmp/vibe-skill-latest.md "$SKILL_PATH" >/dev/null 2>&1 \
  && cp /tmp/vibe-skill-latest.md "$SKILL_PATH" && echo SKILL_UPDATED
```

- **PowerShell**:
```powershell
try { Invoke-WebRequest -UseBasicParsing -Uri https://vibe.egnis.net/skills/deploy-egnis-vibe/SKILL.md -OutFile $env:TEMP\vibe-skill-latest.md
  if ((Get-FileHash $env:TEMP\vibe-skill-latest.md).Hash -ne (Get-FileHash $SKILL_PATH).Hash) { Copy-Item $env:TEMP\vibe-skill-latest.md $SKILL_PATH -Force; Write-Output SKILL_UPDATED } } catch { }
```

- 네트워크 실패 등으로 최신본을 못 받으면 **조용히 건너뛰고 로컬본으로 계속 진행**한다 — 갱신 확인이 배포를 막아선 안 된다.
- `SKILL_UPDATED`가 출력되면 **덮어쓴 SKILL.md를 다시 읽고, 새 내용을 기준으로 1단계부터 진행**한다.

## 1단계 — 로그인 (디바이스 코드)

vibe는 구글 로그인(@egnis.kr) 기반이다. CLI는 **디바이스 코드 플로우**로 세션을 받는다(gh·aws sso 방식). cloudflared 설치는 필요 없고 `curl`만 있으면 된다.

```bash
# (1) 코드 발급
RESP=$(curl -s -X POST https://vibe.egnis.net/__egnis/device/start)
DEVICE_CODE=$(printf '%s' "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["device_code"])')
USER_CODE=$(printf '%s' "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["user_code"])')
```

사용자에게 다음을 그대로 안내한다:
> 브라우저에서 **https://vibe.egnis.net/__egnis/device** 를 열고 코드 **`$USER_CODE`** 를 입력해 승인해주세요. (이미 @egnis.kr로 로그인돼 있으면 코드 입력→승인 한 번이면 끝)

```bash
# (2) 승인될 때까지 폴링 → 세션 토큰 획득 (최대 10분, 5초 간격)
SESSION=""
for i in $(seq 1 120); do
  POLL=$(curl -s -X POST https://vibe.egnis.net/__egnis/device/poll -H 'Content-Type: application/json' -d "{\"device_code\":\"$DEVICE_CODE\"}")
  STATUS=$(printf '%s' "$POLL" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("status",""))')
  if [ "$STATUS" = "approved" ]; then SESSION=$(printf '%s' "$POLL" | python3 -c 'import sys,json;print(json.load(sys.stdin)["session"])'); break; fi
  if [ "$STATUS" = "expired" ]; then echo "코드가 만료됐어요. 1단계부터 다시 실행하세요."; exit 1; fi
  sleep 5
done
[ -n "$SESSION" ] || { echo "승인 대기 시간이 지났어요. 다시 시도하세요."; exit 1; }
```

- 이후 모든 vibe 호출은 `-H "Cookie: __egnis_session=$SESSION"` 으로 인증한다.
- ⚠️ `$SESSION` 토큰은 변수로만 두고 로그·보고서에 출력하지 않는다.
- **Windows(PowerShell)**: 동일 플로우를 `Invoke-RestMethod`로. cloudflared·winget 불필요.
  ```powershell
  $r = Invoke-RestMethod -Method Post https://vibe.egnis.net/__egnis/device/start
  Write-Host "브라우저에서 https://vibe.egnis.net/__egnis/device 열고 코드 $($r.user_code) 입력"
  do { Start-Sleep 5; $p = Invoke-RestMethod -Method Post https://vibe.egnis.net/__egnis/device/poll -ContentType 'application/json' -Body (@{device_code=$r.device_code}|ConvertTo-Json) } until ($p.status -ne 'pending')
  if ($p.status -ne 'approved') { Write-Host '승인 실패/만료'; exit 1 }
  $SESSION = $p.session
  ```
  이후 호출은 `-H "Cookie: __egnis_session=$SESSION"`(curl.exe) 또는 `-Headers @{Cookie="__egnis_session=$SESSION"}`.

## 2단계 — 앱 유형 판별 (정적 vs 서버형)

앱 유형에 따라 필요한 파일과 업로드 옵션이 다르다. **둘 중 하나면 통과**, 둘 다 없으면 중단한다.

- **정적(static)** — 루트에 `index.html`(단일 HTML) 또는 `package.json`(빌드형: `npm install && npm run build` → `dist/` 배포). 업로드 시 `apptype` 생략(기본 static).
- **서버형(server)** — 루트에 **`start.sh`** 가 있으면 서버형(상시 실행). `package.json`은 Node 서버일 때만 선택(python 등은 불필요). 상시 실행이 필요(캘린더 연동·실시간 데이터·소켓 등)하거나 사용자가 "서버형/상시 실행"이라고 하면 이쪽. 업로드 시 `-F "apptype=server"`(필요하면 `-F "datasources=..."`)를 추가한다. → 자세히는 **참조 A·B**.

판별 규칙: `start.sh` 있으면 server, 없고 `index.html`/`package.json` 있으면 static. 셋 다 없으면 "배포할 앱 파일이 없습니다"로 중단.

> **단일 컴포넌트 소스(`.tsx`·`.jsx` 한 장 등)는 그대로 배포 불가** → 빌드형 프로젝트로 감싼다(OS 무관). 최소 구성: `package.json`(`"build": "vite build"` — `tsc &&` 빼서 서드파티 타입오류로 빌드가 막히지 않게), `vite.config.ts`(@vitejs/plugin-react), `tsconfig.json`(strict:false), `index.html`(`<script type="module" src="/src/main.tsx">`), `src/main.tsx`(createRoot 렌더). 클라이언트에서 직접 fetch(구글시트 CSV 등)면 정적으로 충분.

## 2.5단계 — claude.ai 아티팩트 변환 (배포 전 검사, 해당 시에만)

배포할 폴더의 HTML에 **`window.claude`** 문자열이 있으면 claude.ai 아티팩트로 만든 앱이다. 이 앱은 claude.ai 런타임이 주입하는 `window.claude`에 의존하므로 **vibe에 그대로 올리면 데이터가 안 나온다** — 배포 전에 서버형 앱으로 변환한다.

```bash
grep -rl 'window\.claude' --include='*.html' .
```
- **Windows(PowerShell)**: `Select-String -Path *.html -Pattern 'window\.claude' -List`

발견되면 사용자에게 **"claude.ai 아티팩트로 만든 앱이라 변환 후 배포합니다"**라고 알리고 아래 변환을 수행한다.

### 변환 절차

1. **`server.js` 생성** — Node 내장 모듈만 사용(의존성 설치 없음). 정적 파일 서빙 + `process.env.PORT` 리슨 + `POST /api/data`.
   - `/api/data` 바디 `{tool, args}`를 `${process.env.EGNIS_DATA_PROXY}/api/proxy/analytics`로 `'x-egnis-data-key': process.env.EGNIS_DATA_KEY` 헤더와 함께 전달한다(참조 B의 analytics 프록시).
   - **HTML이 실제로 호출하는 도구명만 허용 목록**에 넣고, 그 외 `tool`은 400으로 거부한다.
   - `tool`+`args` 조합을 키로 **10분 인메모리 캐시**를 둔다(같은 화면을 여러 번 열 때 프록시 호출 중복 방지).
   - env(`EGNIS_DATA_PROXY`·`EGNIS_DATA_KEY`)가 없으면 `{ok:false, error:'로컬에서는 데이터 프록시를 쓸 수 없습니다'}`를 돌려준다(로컬 실행 시 정상 동작).

2. **HTML의 `window.claude.use("mcp")` 부팅 블록을 fetch 어댑터로 교체**한다. 이때 **반환은 반드시 `{ payload: r.data, cache: null }` 형태**여야 한다.
   ```js
   // claude.ai callTool 반환 규격 — 본문 파싱 코드가 res.payload를 기대한다
   async function callTool(tool, args) {
     const r = await fetch('/api/data', {
       method: 'POST',
       headers: { 'Content-Type': 'application/json' },
       body: JSON.stringify({ tool, args }),
     }).then((x) => x.json())
     if (!r.ok) throw new Error(r.error)
     return { payload: r.data, cache: null }   // ← 맨몸으로 r.data만 반환하면 "응답 형식이 다릅니다" 오류
   }
   ```
   ⚠️ `{ payload, cache }`로 감싸지 않고 데이터를 그대로 반환하면 화면이 **"응답 형식이 다릅니다"**로 죽는다(실사고).

3. **`window.claude.use("sample")` 등 다른 capability는 이식 불가** — 프록시에 대응하는 데이터가 없다. 해당 호출이 실패하면 그 영역을 숨기는 **기존 동작을 그대로 보존**한다(억지로 대체 데이터를 만들지 않는다).

4. **`package.json`**(`{"name": "<슬러그>", "private": true}`)과 **`start.sh`**를 만든다.
   ```bash
   #!/usr/bin/env bash
   node server.js
   ```

5. **claude.ai 안내 문구 교체** — "claude.ai에서 열어 주세요" 류의 문구는 vibe에서 의미가 없으므로 **"데이터를 불러오지 못했습니다. 잠시 후 새로고침해 주세요."**로 바꾼다.

### 업로드 시 주의

변환된 앱은 서버형 + analytics 데이터소스이므로 5단계 curl에 **`-F "apptype=server" -F "datasources=analytics"`를 반드시 포함**한다(참조 B).
- 재배포는 선언 없이 올려도 서버가 기존 선언을 승계하지만, **신규 배포는 명시가 필수**다(빠뜨리면 프록시 env가 주입되지 않아 데이터가 안 나온다).

## 3단계 — zip 생성

무겁거나 민감한 경로는 제외한다.
```bash
rm -f /tmp/vibe-deploy.zip
zip -qr /tmp/vibe-deploy.zip . -x 'node_modules/*' '.git/*' 'dist/*' '.env*' '*.DS_Store'
```
- `.vibe/` 폴더(소스를 내려받으면 생기는 `.vibe/base.json`)는 **빼지 않는다** — 어느 버전을 고쳤는지 서버에 알려주는 파일이다("공동 편집자로 배포하기" 참고).
- **Windows(PowerShell)**: `zip` CLI가 없으니 내장 `tar.exe`(bsdtar)를 쓴다. **`Compress-Archive`는 금지** — 엔트리를 백슬래시(`src\x.tsx`)로 기록해 리눅스 빌드 컨테이너가 `src/` 디렉터리를 못 만들어 빌드가 깨진다.
  ```powershell
  Push-Location $appDir
  tar.exe -a -c -f "$env:TEMP\vibe-deploy.zip" index.html package.json package-lock.json vite.config.ts tsconfig.json src
  # .vibe 폴더가 있으면 위 목록 끝에 .vibe 도 함께 넣는다
  Pop-Location
  tar.exe -tf "$env:TEMP\vibe-deploy.zip"   # 엔트리가 src/x.tsx 처럼 '/' 인지 검증. '\'면 그 zip은 버린다.
  ```
  node_modules·dist·.git·.env은 **나열하지 않는 방식**으로 제외(필요한 항목만 열거). 와일드카드 제외가 필요하면 bsdtar `--exclude` 사용.

## 4단계 — 주소 사용 가능 확인 (필수)

```bash
curl -s -H "Cookie: __egnis_session=$SESSION" "https://vibe.egnis.net/api/slug-check/<슬러그>"
```
- `available: true` → 진행.
- `mine: true` → 이미 내가 쓰는 주소(기존 서비스). 사용자에게 **"기존 '<title>'을 새 버전으로 업데이트할까요?"** 확인을 받은 뒤에만 진행.
  `role:"collaborator"`면 남의 서비스에 **공동 편집자**로 배포하는 것이다 — 아래 "공동 편집자로 배포하기"를 따른다.
- 그 외(`available: false`) → 다른 사람의 주소이거나 예약어. 다른 슬러그를 제안하고 중단.

## 5단계 — 업로드

먼저 기준 버전을 읽는다 — 폴더에 `.vibe/base.json`이 있으면(내려받은 소스) 그 version, 없으면 빈 값(빈 값은 "기준 정보 없음"으로 처리된다).
```bash
BASE=$(python3 -c 'import json;print(json.load(open(".vibe/base.json")).get("version",""))' 2>/dev/null)
```
정적 앱(기본):
```bash
curl -s -X POST https://vibe.egnis.net/upload \
  -H "Cookie: __egnis_session=$SESSION" \
  -F "file=@/tmp/vibe-deploy.zip" \
  -F "slug=<슬러그>" -F "title=<제목>" -F "baseVersion=$BASE" \
  -F "description=<설명>" -F "tags=<태그>" -F "usage=<사용법>"
```
서버형 앱 — `apptype=server`를, 공용 데이터를 쓰면 `datasources=...`도 같은 curl에 함께 넣는다:
```bash
curl -s -X POST https://vibe.egnis.net/upload \
  -H "Cookie: __egnis_session=$SESSION" \
  -F "file=@/tmp/vibe-deploy.zip" \
  -F "slug=<슬러그>" -F "title=<제목>" -F "baseVersion=$BASE" \
  -F "apptype=server" -F "datasources=google" \
  -F "description=<설명>" -F "tags=<태그>"
```
- 응답 `{ok:true, jobId}`. `ok:false`면 error를 그대로 보여주고 중단(제목 누락, 다른 사람 소유 슬러그 403, 용량 초과 등).
- **처음부터 비공개로 올리기**: 사용자가 "비공개로", "나만 보게" 등을 요청하면 **새 서비스 첫 배포**의 curl에 `-F "visibility=restricted"`를 추가한다. 첫 공개 전에 소유자만 접근으로 잠기고 새 앱 공지도 나가지 않는다. 이미 배포된 서비스에는 적용되지 않으며(작업 로그에 안내), 공개 범위 변경은 서비스 상세의 접근 권한에서 한다.
- **409 "더 최신 버전(vN, …)이 이미 배포되어 있습니다"** → "공동 편집자로 배포하기" 3번을 따른다(임의로 `force=1`을 붙이지 않는다).
- **용량 제한 기본 50MB.** 50MB를 넘는 한도는 **관리자 승인(사용자별 설정)**이 있어야 하고, 서버가 판단한다. node_modules·dist는 3단계 제외 패턴으로 빠지므로 보통 문제없다. 초과하면 무거운 파일을 빼고 다시 zip한다.
- **zip이 45MB를 넘으면 위 `-F "file=@..."` 대신 아래 "대용량 zip — 직접 업로드"를 쓴다.** 회사 도메인 앞단(Cloudflare)이 100MB 넘는 요청을 끊기 때문에, 큰 zip은 저장소(R2)에 바로 올리고 플랫폼이 거기서 가져간다. 직접 업로드 상한은 **500MB**(승인된 개인 한도까지).
- **Windows(PowerShell 5.x) 한글 주의**: native exe 인자가 시스템 코드페이지(CP949)로 인코딩돼 `-F "title=한글"` 직접 전달 시 메타데이터가 깨진다. 한글 값은 **UTF-8(BOM 없음) 파일로 쓰고 `-F "field=<파일"`** 로 읽힌다. 한글 사용자 경로(`C:\Users\강윤선\…`)는 curl이 파일을 못 여는 케이스가 있으니 zip·메타파일을 **ASCII 경로(`C:\Users\Public\vibe`)**에 둔다.
  ```powershell
  $work = "C:\Users\Public\vibe"; New-Item -ItemType Directory -Force $work | Out-Null
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText("$work\title.txt", "리뷰 인사이트 대시보드", $utf8)
  $base = if (Test-Path .vibe\base.json) { (Get-Content .vibe\base.json -Raw | ConvertFrom-Json).version } else { '' }
  curl.exe -s -X POST https://vibe.egnis.net/upload -H "Cookie: __egnis_session=$SESSION" `
    -F "file=@$work\vibe-deploy.zip" -F "slug=<슬러그>" -F "title=<$work\title.txt" -F "description=<$work\desc.txt" -F "baseVersion=$base"
  ```

### 대용량 zip — 직접 업로드 (45MB 초과)

순서: ① 업로드 URL 발급(`/api/upload/presign`) → ② 그 URL로 zip을 R2에 직접 PUT → ③ `/upload`에 `uploadKey`와 메타데이터를 보낸다(`file` 대신). 6단계부터는 같다.
- 발급 URL은 **15분 안에 PUT을 시작**해야 하고, 발급받은 `uploadKey`는 **본인·같은 슬러그·1회**만 쓸 수 있다. 실패하면 ①부터 다시 한다.
- 개인 한도(기본 50MB, 관리자 승인 시 최대 500MB)를 넘는 크기는 ①에서 바로 거부된다. 그 error를 그대로 보여주고 중단한다.
- PUT의 `Content-Type`은 반드시 `application/zip`(서명에 포함됨 — 다르면 R2가 403).

```bash
ZIP=/tmp/vibe-deploy.zip
BYTES=$(wc -c < "$ZIP" | tr -d ' ')
# ① 발급
P=$(curl -s -X POST https://vibe.egnis.net/api/upload/presign \
  -H "Cookie: __egnis_session=$SESSION" -H 'Content-Type: application/json' \
  -d "{\"slug\":\"<슬러그>\",\"bytes\":$BYTES}")
UPLOAD_KEY=$(printf '%s' "$P" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("uploadKey") or "")')
PUT_URL=$(printf '%s' "$P" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("putUrl") or "")')
[ -n "$UPLOAD_KEY" ] || { printf '%s\n' "$P"; exit 1; }   # ok:false → error 안내 후 중단
# ② R2로 직접 PUT (플랫폼·Cloudflare 프록시 미경유)
curl -sf -X PUT --upload-file "$ZIP" -H 'Content-Type: application/zip' "$PUT_URL" || { echo "R2 업로드 실패"; exit 1; }
# ③ 배포 요청 — file 대신 uploadKey. 나머지 필드(apptype·datasources 포함)는 5단계와 같다.
curl -s -X POST https://vibe.egnis.net/upload \
  -H "Cookie: __egnis_session=$SESSION" \
  -F "uploadKey=$UPLOAD_KEY" \
  -F "slug=<슬러그>" -F "title=<제목>" -F "baseVersion=$BASE" \
  -F "description=<설명>" -F "tags=<태그>" -F "usage=<사용법>"
```
- **Windows(PowerShell)**: 같은 순서. 한글 메타데이터는 위처럼 UTF-8 파일(`-F "title=<파일"`)로 넘긴다.
  ```powershell
  $work = "C:\Users\Public\vibe"; $zip = "$work\vibe-deploy.zip"
  $bytes = (Get-Item $zip).Length
  $base = if (Test-Path .vibe\base.json) { (Get-Content .vibe\base.json -Raw | ConvertFrom-Json).version } else { '' }
  $p = Invoke-RestMethod -Method Post https://vibe.egnis.net/api/upload/presign `
    -Headers @{Cookie="__egnis_session=$SESSION"} -ContentType 'application/json' `
    -Body (@{slug='<슬러그>'; bytes=$bytes} | ConvertTo-Json)
  if (-not $p.ok) { Write-Host $p.error; exit 1 }
  curl.exe -sf -X PUT --upload-file $zip -H "Content-Type: application/zip" $p.putUrl
  if ($LASTEXITCODE -ne 0) { Write-Host 'R2 업로드 실패'; exit 1 }
  curl.exe -s -X POST https://vibe.egnis.net/upload -H "Cookie: __egnis_session=$SESSION" `
    -F "uploadKey=$($p.uploadKey)" -F "slug=<슬러그>" -F "title=<$work\title.txt" -F "description=<$work\desc.txt" -F "baseVersion=$base"
  ```
  `Invoke-RestMethod`는 4xx에서 예외를 던진다 — 예외 메시지의 응답 본문(error)을 그대로 보여주고 중단한다.

## 6단계 — 빌드 로그 스트리밍

```bash
curl -sN --max-time 420 -H "Cookie: __egnis_session=$SESSION" "https://vibe.egnis.net/events/<jobId>"
```
SSE 로그를 사용자에게 보여주고, `event: done`의 JSON이 최종 결과다.
- **`event: done` 직전 스트림이 끊길 수 있다**(curl exit 18 / partial transfer 등). 이때 **빌드 실패로 단정하지 말 것** — 같은 jobId로 `/events/<jobId>`에 재접속하면 처음부터 다시 재생되며 `event: done`까지 수신된다. done의 JSON으로 성공/실패를 판정한다.

## 7단계 — 결과 안내

- 성공: `https://<슬러그>.egnis.net` (사내 인증 적용, DNS 전파 최대 1분) + 허브 상세 `https://vibe.egnis.net/s/<슬러그>`
- 같은 슬러그로 다시 실행하면 새 버전으로 교체된다.
- 검증용 프로토타입이며 정식 프로덕션 배포가 아님을 함께 안내한다.

## 공동 편집자로 배포하기

소유자가 서비스 설정에서 나를 **공동 편집자**로 지정했다면, 내 PC에서 그 서비스의 새 버전을 배포할 수 있다. 할 수 있는 것은 **새 버전 배포와 소스 내려받기뿐**이다(제목·설명, 접근 권한, 삭제, 배포 토큰은 소유자만).

1. **최신 소스 받기** (1단계 로그인 후). 빈 작업 폴더에 푼다:
   ```bash
   curl -sf -H "Cookie: __egnis_session=$SESSION" -o /tmp/<슬러그>-src.zip "https://vibe.egnis.net/api/service/<슬러그>/source"
   mkdir -p ~/vibe/<슬러그> && unzip -oq /tmp/<슬러그>-src.zip -d ~/vibe/<슬러그> && cd ~/vibe/<슬러그>
   ```
   - Windows(PowerShell): `curl.exe -sf -H "Cookie: __egnis_session=$SESSION" -o "$work\src.zip" "https://vibe.egnis.net/api/service/<슬러그>/source"` 후 `tar.exe -xf "$work\src.zip" -C <작업폴더>`.
   - 실패 시(`-f`라 본문이 안 보이면 `-f` 없이 다시 호출해 error 확인): 403 = 공동 편집자가 아님(소유자에게 지정 요청), 404 = 보관된 소스 없음(기능 도입 전 배포 — 소유자에게 한 번 다시 배포해 달라고 요청), 503 = 플랫폼 소스 보관 꺼짐(관리자 문의).
   - 받은 폴더의 `.vibe/base.json`(`{slug, version, sha256}`)은 **지우지 않는다** — 다음 배포 때 "어느 버전을 고쳤는지" 서버에 알려준다.
2. **수정 후 평소처럼 3~7단계로 배포**한다. 4단계 slug-check는 `mine:true, role:"collaborator"`. 5단계 curl은 `-F "baseVersion=$BASE"`를 그대로 보낸다. 제목·설명·태그·데이터소스는 소유자 값이 유지된다(보내도 무시).
3. **409 "더 최신 버전(vN, 올린 사람)이 이미 배포되어 있습니다"** → 내가 소스를 받은 뒤 다른 사람이 새 버전을 배포했다는 뜻이다. 그대로 덮어쓰면 그 사람의 변경이 사라진다고 사용자에게 설명하고, 기본은 **1번부터 최신 소스를 다시 받아** 내 변경을 반영한 뒤 배포한다.
   - `-F "force=1"`은 사용자가 "그 변경을 덮어써도 된다"고 **명시적으로 확인한 경우에만** 붙인다.
4. 배포가 끝나면 소유자에게 Slack DM으로 알림이 간다.

---

# 참조 A — 서버형 앱

정적 빌드가 아니라 프로세스가 계속 떠 있어야 하면 서버형으로 배포한다.

- **규약**: 루트에 `start.sh`(실행 진입점), 앱은 환경변수 `PORT`로 리슨. package.json 불필요, node·python 모두 가능.
  ```bash
  # start.sh 예시 (Node)
  node server.js
  # start.sh 예시 (Python)
  pip3 install --user -r requirements.txt && python3 app.py
  ```
- 업로드 시 5단계 curl에 `-F "apptype=server"`를 추가한다.

### 정적 자산 캐시 방지 (서버형이 js/css를 직접 서빙할 때 필수)
서버형 앱이 `app.js`·`style.css` 같은 정적 자산을 직접 서빙하면, **재배포해도 브라우저가 옛 파일을 캐시해 변경이 안 보이는** 함정이 흔하다(강력 새로고침으로도 안 풀리는 케이스 있음). 두 가지를 함께 적용한다:
- **응답 헤더**: 정적 자산에 `Cache-Control: no-store, no-cache, must-revalidate`.
- **버전 쿼리**: HTML에서 `<script src="app.js?v=N">`·`<link href="style.css?v=N">`처럼 참조하고, 코드를 바꿀 때 `N`을 올린다(파일 URL이 달라져 브라우저가 무조건 새로 받음). 서버는 `req.url.split('?')[0]`로 쿼리를 떼고 파일을 찾는다.
- **판별법**: vibe 엣지는 js/css를 캐시하지 않으므로 변경이 안 보이면 거의 항상 **브라우저 캐시**다. `view-source:https://<slug>.egnis.net/app.js?nocache=99`로 받아 새 코드가 있으면 서버는 정상(= 버전쿼리로 해결).

### 접속자 이메일 (로그인 사용자 확인)
서버형 앱은 요청 헤더 **`X-Egnis-User-Email`** 로 로그인 사용자를 확인한다(인증 게이트가 위조 불가하게 주입).
⚠️ **`Cf-Access-Authenticated-User-Email`(Cf- prefix)는 cloudflared 터널을 통과하지 못해 서버형 컨테이너엔 도달하지 않는다** — 반드시 `X-Egnis-User-Email`을 1순위로 읽는다(옛 앱 호환용으로 cf-access를 폴백에 둘 수는 있으나 실제로는 비어 온다). 헤더가 없으면 거부한다(로컬 개발만 폴백 허용).
```js
function userEmail(req) {
  return String(req.headers['x-egnis-user-email'] || req.headers['cf-access-authenticated-user-email'] || (isLocal(req) ? 'you@egnis.kr' : '')).trim()
}
```

# 참조 B — 공용 데이터 연동 (datasources)

사내 공용 데이터(Cafe24 매출, Google 캘린더·임직원 명부 등)를 쓰는 **서버형** 앱은 키를 직접 들고 다니지 않는다. **플랫폼이 토큰을 중앙 관리**하고, 앱은 프록시만 호출한다.

- 업로드 시 `-F "datasources=<id>"` 선언(여러 개면 쉼표). 사용 가능 목록:
  - `analytics` — EGNIS Analytics MCP(Cafe24 매출·광고). 예: 자사몰 인사이트
  - `google` — Google Workspace(캘린더·임직원 Directory·Drive). 예: 회의실 예약
  - `slack` — Slack 채널·메시지 **읽기**(공용 봇, 읽기 전용). 예: 채널 요약·알림 모니터
  - `notion` — Notion 페이지·DB **읽기**(공용 통합, 공유된 페이지만). 예: 위키·문서 조회
  - `kv` — 서버앱 영속 KV 저장(R2). 재배포에도 데이터 유지. `POST /api/proxy/kv {op,key,value}`
  - 사용 가능 여부 확인: `curl -s -H "Cookie: __egnis_session=$SESSION" https://vibe.egnis.net/api/datasources` (`available:true`면 바로 사용)
- 모든 서버형 컨테이너에 **토큰이 아니라** 프록시 접근 정보가 env로 주입된다: `EGNIS_DATA_PROXY`(플랫폼 내부 주소), `EGNIS_DATA_KEY`(이 앱 전용 프록시 키), `EGNIS_APP_SLUG`.
  - 앱 식별은 `EGNIS_DATA_KEY`에서 플랫폼이 직접 꺼낸다. **`x-egnis-app` 헤더는 보내지 않는다**(보내려면 반드시 자기 slug — 다르면 403).
  - 쓸 수 있는 프록시 = 선언한 datasources + 관리자가 부여한 프록시 권한. 그 밖의 프록시를 부르면 `403 PROXY_NOT_GRANTED` — datasources에 선언해 재배포하거나 관리자에게 권한을 요청한다.

### kv 프록시 — 서버앱 영속 저장(재배포에도 유지)
컨테이너 파일시스템은 ephemeral이라 앱이 파일에 직접 쓴 데이터는 재배포마다 사라진다. `datasources=kv` 선언 후 `POST /api/proxy/kv`로 R2 기반 영속 저장소를 쓴다. 실제 저장 위치는 `kv/<내 app_slug>/<key>`로 앱마다 격리되며, key는 `[a-zA-Z0-9._/-]`만 허용(`../` 등 경로탈출 거부), value는 키당 5MB 상한.
```js
// put
await fetch(`${process.env.EGNIS_DATA_PROXY}/api/proxy/kv`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'x-egnis-data-key': process.env.EGNIS_DATA_KEY },
  body: JSON.stringify({ op: 'put', key: 'history.json', value: JSON.stringify(data) }),
})
// get (키 없으면 j.value === null)
const j = await (await fetch(`${process.env.EGNIS_DATA_PROXY}/api/proxy/kv`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'x-egnis-data-key': process.env.EGNIS_DATA_KEY },
  body: JSON.stringify({ op: 'get', key: 'history.json' }),
})).json()
const data = j.value ? JSON.parse(j.value) : null
```
자세한 사용법·제약은 `docs/kv-store.md` 참고.

### 프록시 응답 형태 (중요 — 모르면 데이터가 0건으로 나온다)
프록시는 Google/Cafe24 원문을 **`{ ok, data }`로 한 번 감싸서** 돌려준다. **반드시 `result.data` 안에서 원문 필드를 찾는다**(최상위가 아니다). 실패 시 `{ ok:false, error }`.
```js
// req = 지금 처리 중인 사용자 요청. 인증 게이트가 붙여 준 x-egnis-user-token을 그대로 전달해야
// 플랫폼이 "그 사용자가 지금 이 앱에 접속했다"를 확인하고 body.user로 impersonate한다(없거나 다른 사용자면 403).
async function callGoogle(req, body) {
  const r = await fetch(`${process.env.EGNIS_DATA_PROXY}/api/proxy/google`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-egnis-data-key': process.env.EGNIS_DATA_KEY,
      'x-egnis-user-token': String(req.headers['x-egnis-user-token'] || ''), // 받은 값 그대로(10분 유효)
    },
    body: JSON.stringify(body),
  })
  const j = await r.json()
  if (!j.ok) throw new Error(j.error)   // 토큰/scope/권한 오류
  return j.data                          // ← Google 원문은 j.data 안에 있다
}
// Directory: j.data.users  /  FreeBusy: j.data.calendars  /  이벤트 생성: j.data.id, j.data.htmlLink
```
흔한 함정: `j.users`로 접근하면 `undefined` → 화면에 에러 없이 **"0명"**으로 보인다. 항상 `j.data.users`.
- `body.user`는 반드시 그 요청의 로그인 사용자(`x-egnis-user-email`)여야 한다. 토큰은 (앱, 사용자, 10분)에 묶여 있어 다른 사용자 이름으로 호출하거나 요청 없이 백그라운드에서 사용자 캘린더를 부를 수 없다.

### google 프록시 — 요청 형태와 승인 scope
`POST /api/proxy/google` 바디: `{ user, api, method, path, query?, body?, scopes }`
- `api`: `calendar` | `directory` | `drive`(화이트리스트).
- `user`: 접속자 본인 이메일(서버형 헤더 **`X-Egnis-User-Email`**에서 읽는다 — Cf-Access는 터널을 못 넘으니 쓰지 않는다). Directory는 플랫폼이 관리자 계정으로 대행하므로 아무 사내 이메일이나 무방.
- `scopes`: **아래 승인 목록만 쓴다.** 미승인 scope를 넣으면 `unauthorized_client`로 실패한다.

**현재 운영 승인 scope (이 목록만 사용. `.freebusy` 같은 세부 scope는 미승인이라 실패):**
```
https://www.googleapis.com/auth/calendar                                    # 캘린더 전반(FreeBusy·이벤트 포함). FreeBusy엔 calendar.freebusy 대신 이걸 쓴다
https://www.googleapis.com/auth/calendar.events                             # 이벤트 생성/수정
https://www.googleapis.com/auth/admin.directory.user.readonly               # 임직원 조회
https://www.googleapis.com/auth/admin.directory.resource.calendar.readonly  # 회의실 리소스 목록
https://www.googleapis.com/auth/drive.file                                  # 앱이 만든 Drive 파일
```
새 scope가 필요하면 Workspace 관리자 승인이 선행되어야 한다(설계: docs/google-workspace-broker.md). Gmail은 보안상 미승인.

```js
// FreeBusy (scopes는 calendar — calendar.freebusy 아님!)
await callGoogle(req, { user: me, api: 'calendar', method: 'POST', path: '/freeBusy',
  body: { timeMin, timeMax, timeZone: 'Asia/Seoul', items: [{ id: me }, { id: roomEmail }] },
  scopes: ['https://www.googleapis.com/auth/calendar'] })   // → .calendars
// 임직원 목록
await callGoogle(req, { user: me, api: 'directory', method: 'GET', path: '/users',
  query: { domain: 'egnis.kr', maxResults: '500', viewType: 'domain_public' },
  scopes: ['https://www.googleapis.com/auth/admin.directory.user.readonly'] })  // → .users
// 회의실 리소스
await callGoogle(req, { user: me, api: 'directory', method: 'GET', path: '/customer/my_customer/resources/calendars',
  scopes: ['https://www.googleapis.com/auth/admin.directory.resource.calendar.readonly'] })  // → .items
// 이벤트 생성(내 캘린더 + 회의실 attendee)
await callGoogle(req, { user: me, api: 'calendar', method: 'POST', path: '/calendars/primary/events',
  query: { sendUpdates: 'all' },
  body: { summary, start: { dateTime, timeZone: 'Asia/Seoul' }, end: { dateTime, timeZone: 'Asia/Seoul' },
          attendees: [{ email: roomEmail, resource: true }] },
  scopes: ['https://www.googleapis.com/auth/calendar', 'https://www.googleapis.com/auth/calendar.events'] })
```

### analytics 프록시
analytics도 동일한 `{ ok, data }` 래핑이다(`result.data`에 Cafe24 응답). 바디는 `{ tool, args }`:
```js
const r = await fetch(`${process.env.EGNIS_DATA_PROXY}/api/proxy/analytics`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'x-egnis-data-key': process.env.EGNIS_DATA_KEY },
  body: JSON.stringify({ tool: 'get_cafe24_sales_summary', args: { brand: 'cloop', datePreset: 'last_7_days' } }),
}).then((x) => x.json())
// 매출 데이터는 r.data 안에 (r.data.totals, r.data.rows ...)
```
- **읽기 전용 도구만 허용**: `tool`은 `get_cafe24_*` 또는 `list_supported_brands`로 시작해야 한다(그 외는 "허용되지 않은 도구" 400). 자주 쓰는 도구: `get_cafe24_sales_summary`(일별 매출/주문/환불), `get_cafe24_product_sales`(상품 랭킹), `get_cafe24_referrer_traffic`(유입), `list_supported_brands`(몰 목록).
- `args`의 `brand`는 몰 키(cloop/sprint/labnosh/braye/oneday1ball/groceryseoul/exerapy/drlabnosh/medileeds). 기간은 `datePreset`(today/yesterday/last_7_days/last_30_days/...) 또는 `startDate`+`endDate`(YYYY-MM-DD, KST).

### slack / notion 프록시 (읽기 전용)
둘 다 동일한 `{ ok, data }` 래핑(`result.data`에 원문). **읽기 전용** — 화이트리스트 밖 호출은 400. 공용 봇/통합이라 "누가 호출하든 같은 권한"(개인별 권한 아님).
```js
// Slack: 채널 메시지 — 바디는 { method, query }
const r = await fetch(`${process.env.EGNIS_DATA_PROXY}/api/proxy/slack`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'x-egnis-data-key': process.env.EGNIS_DATA_KEY },
  body: JSON.stringify({ method: 'conversations.history', query: { channel: 'C123456', limit: 50 } }),
}).then((x) => x.json())
// 메시지는 r.data.messages

// Notion: 페이지 본문(블록) — 바디는 { method, path }
const n = await fetch(`${process.env.EGNIS_DATA_PROXY}/api/proxy/notion`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'x-egnis-data-key': process.env.EGNIS_DATA_KEY },
  body: JSON.stringify({ method: 'GET', path: '/v1/blocks/PAGE_ID/children' }),
}).then((x) => x.json())
// 블록은 n.data.results
```
- **Slack 허용 메서드**(읽기 전용): `conversations.list/history/replies/info`, `users.list/info`. 메시지 전송·검색(`chat.*`·`search.*`)은 차단. `query`에 채널·limit·cursor 등 슬랙 API 파라미터를 넣는다.
- **Notion 허용**: `GET /v1/pages/{id}` · `GET /v1/blocks/{id}/children` · `GET /v1/databases/{id}` · `POST /v1/databases/{id}/query` · `POST /v1/search`. 생성·수정·삭제 차단. **통합에 공유된 페이지만** 접근된다(공유 안 된 페이지는 노션이 거부).

---

# 참조 C — 대용량 미디어(R2 미디어 스토리지)

이미지·비디오 아카이브 등 **미디어가 zip 50MB 상한에 안 들어가거나**, **외부 CDN URL(fbcdn 등
서명 만료형)을 그대로 저장하려는 경우** 쓴다.

⚠️ **만료형 외부 URL을 데이터에 저장하지 말 것.** 메타 광고 라이브러리 앱이 fbcdn URL(`...&oe=...`
만료 파라미터 포함)을 그대로 DB에 저장했다가, 며칠 뒤 서명이 만료되며 저장된 URL이 전부 죽는
사고가 있었다(4,052건 전멸 확인). **수집 시점에 미디어를 R2로 옮겨 영구 URL로 저장**해야 한다.

## 사용법
1단계(디바이스 코드 세션)로 `$SESSION`을 얻은 뒤 그대로 이어서 쓴다.

```bash
# 1) 활성화 여부 확인 — enabled:false면 관리자에게 R2 셋업(docs/media-storage.md)을 요청하라고 안내하고 중단.
curl -s -H "Cookie: __egnis_session=$SESSION" https://vibe.egnis.net/api/media-policy

# 2) presign 발급
curl -s -X POST https://vibe.egnis.net/api/media/presign \
  -H "Cookie: __egnis_session=$SESSION" -H "Content-Type: application/json" \
  -d '{"filename":"ad-123.jpg","contentType":"image/jpeg","bytes":204800}'
# → { ok:true, key, putUrl, publicUrl, headers:{ "Content-Type": "image/jpeg" } }

# 3) putUrl로 파일을 R2에 직접 업로드 (플랫폼을 거치지 않음 — Content-Type을 headers 그대로 지정)
curl -s -X PUT --upload-file ./ad-123.jpg -H "Content-Type: image/jpeg" "<putUrl>"

# 4) 업로드 확인(R2 실측 확인 후 쿼터 확정)
curl -s -X POST https://vibe.egnis.net/api/media/confirm \
  -H "Cookie: __egnis_session=$SESSION" -H "Content-Type: application/json" \
  -d '{"key":"<2단계 응답의 key>"}'
# → { ok:true, key, bytes, publicUrl }

# 이후 publicUrl(https://media.egnis.net/...)을 데이터(DB·JSON 등)에 저장한다. fbcdn류 URL은 저장하지 않는다.
```

JS(fetch) 예시 — 서버형 앱의 수집 스크립트에서:
```js
async function uploadToMedia(file, session) {
  const presign = await fetch('https://vibe.egnis.net/api/media/presign', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Cookie: `__egnis_session=${session}` },
    body: JSON.stringify({ filename: file.name, contentType: file.type, bytes: file.size }),
  }).then((r) => r.json())
  if (!presign.ok) throw new Error(presign.error) // enabled:false·용량초과·쿼터초과 등

  await fetch(presign.putUrl, { method: 'PUT', headers: presign.headers, body: file }) // 플랫폼 미경유 직접 업로드

  const confirm = await fetch('https://vibe.egnis.net/api/media/confirm', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Cookie: `__egnis_session=${session}` },
    body: JSON.stringify({ key: presign.key }),
  }).then((r) => r.json())
  return confirm.publicUrl // 이 영구 URL을 데이터에 저장 (fbcdn 같은 만료형 URL 대신)
}
```

## 제약
- **쿼터**: 개당 500MB · 1인당 5GB · 전체 50GB. `presign`이 신고 크기 기준으로 미리 거부하고,
  `confirm`이 R2 실측 크기로 갱신한다(정직한 사용량 집계).
- **mime 화이트리스트**: `image/png·jpeg·gif·webp`, `video/mp4·webm·quicktime`만 허용. 그 외는 400.
- **공개 범위 주의**: `publicUrl`은 **인증 없는 공개 URL**(추측 불가능한 UUID 기반이지만 그래도 공개).
  사내 비밀 자료·개인정보를 올리지 말 것 — 공개물(광고 소재 등)·자체 제작물 용도로만 쓴다.
- `enabled:false`면(관리자가 R2를 아직 셋업하지 않음) presign·confirm·list 라우트는 모두 503을
  반환한다 — 사용자에게 관리자 셋업(`docs/media-storage.md`)을 요청하라고 안내하고 중단한다.

---

# 검증 및 주의사항

## 배포 후 검증
- **빌드 로그(6단계)의 `event: done`이 곧 검증이다.** "데이터 연결: google", "주소 전파 완료"까지 나오면 성공. 추가 curl 검증은 보통 불필요하다.
- 앱 도메인 확인은 같은 `$SESSION`으로 된다(세션 쿠키는 `.egnis.net` 전체 공유). `curl -H "Cookie: __egnis_session=$SESSION" https://<슬러그>.egnis.net/`. 단 **서버형의 실제 동작은 브라우저로 접속해 확인하는 게 정석**이다(접속자 이메일 헤더가 그때 주입됨).
- 배포 직후 잠깐 "Unable to find Access application"이 뜰 수 있다 — DNS 전파 지연. 1~2분 후 새로고침하면 된다.

## 로컬 검증
- **`index.html`을 Finder에서 `file://`로 직접 열지 말 것.** `/api/...` 라우트가 없고, `/이미지.webp` 절대경로가 파일시스템 루트로 잘못 해석돼 깨진다.
- 검증은 반드시 **서버 실행**으로: 서버형은 `PORT=8080 node server.js` 후 `http://localhost:8080`. (데이터소스 프록시는 운영에만 있어 로컬에선 datasource 호출이 실패할 수 있다 — 정상이며, 배포 후 브라우저로 확인.)
- 이미지는 `/logo.webp`(절대경로)보다 `logo.webp`(상대경로)가 안전하다.

## 안전 규칙
- **사용자가 명시적으로 배포를 요청할 때만 실행한다. 스스로 판단해 배포하지 않는다.**
- `.env`·서비스계정 JSON 등 **비밀 파일이 zip에 들어가지 않게** 제외 패턴을 유지한다. 비밀은 datasources/프록시로 처리하고 코드·zip에 넣지 않는다.
- 디바이스 플로우의 `$SESSION`(세션 토큰)은 **로그·보고서에 노출하지 않는다** — 변수로만 둔다.
- 다른 사람 소유 슬러그면 서버가 403으로 거부한다 — 우회하지 말고 다른 슬러그를 제안한다.
