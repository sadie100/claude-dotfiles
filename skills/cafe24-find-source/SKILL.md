---
name: cafe24-find-source
description: >-
  라이브 Cafe24 페이지에서 렌더된 스타일/스크립트가 "어느 원본 스킨 소스 파일(CSS/JS)"에서
  왔는지 역추적한다. Cafe24 HTML 옵티마이저가 여러 파일을 optimizer.php/optimizer_user.php
  번들 하나로 합쳐버려서, 브라우저에서 파일명을 검색해도 원본이 안 보이는 상황을 해결한다.
  입력은 CSS 셀렉터 / JS 코드조각·심볼, 또는 "화면의 이 요소" 같은 설명 둘 다 받는다.
  Use this whenever working on a Cafe24 / SmartDesign skin and you need to know which
  source file to edit for a style or script you see on the live site — triggers like
  "이 스타일 어느 파일이야", "이 요소 CSS 원본 찾아줘", "번들에서 원본 파일 찾아", "이 JS 어디서 와",
  "which file is this rule in", "find the source file for this element", especially when
  the repo is a partial mirror and the file isn't obviously present locally.
---

# cafe24-find-source

## 왜 필요한가

Cafe24는 HTML 옵티마이저가 켜진 몰에서 스킨의 CSS/JS를 **번들 하나로 합쳐** 문서 하단에서 로드한다.

- `ind-script/optimizer.php` = Cafe24 기본 파일 (`framework/…`, `program/…`)
- `ind-script/optimizer_user.php` = **유저 스킨 파일** (`sdedesign/<skin>/…`) ← 우리가 고칠 대상

그래서 브라우저에서 `.some-class`나 스크립트 파일명을 검색해도 개별 `<link>`/`<script src>`가 아니라
번들 URL(`optimizer_user.php?filename=<암호>&type=css|js`)만 나온다. 이 스킬은 그 번들의 `filename`
파라미터를 디코드해 **원본 소스 파일 목록을 복원**하고, raw fetch + grep으로 **정확한 파일 1개**를 짚는다.

## 입력 두 가지

1. **셀렉터/심볼 직접 지정** — `#coupon-list .coupon-body.open` (CSS) 또는 `oMyCoupon`, `fetchFreeShipThreshold` 같은 JS 코드조각.
2. **화면 요소 설명** — "상품 가격 밑 쿠폰 요약 박스". 이 경우 먼저 브라우저 스냅샷으로 해당 요소를 찾아
   **CSS 셀렉터(또는 JS면 눈에 띄는 코드 문자열)로 환산**한 뒤 1번과 동일하게 진행한다.

반드시 **라이브(또는 테스트 스킨) URL**이 필요하다. 없으면 사용자에게 물어본다.

## 워크플로우

### 0. 브라우저 준비
공유 디버깅 크롬을 쓴다 (`chrome-devtools-shared` 또는 `playwright-shared` MCP — 프로젝트 규칙 준수).
내가 연 탭에서만 작업하고, 남의 탭/브라우저를 건드리지 않는다.
- **모바일 스킨 주의:** Cafe24는 UA로 PC/모바일 스킨을 가른다. 모바일 대상이면 모바일 UA로 접근하거나
  `.../skin-mobileNN/...` 명시 스킨 경로를 쓴다. 데스크톱 크롬으로 `cloop.co.kr/...`을 열면 PC 스킨이 뜬다.

### 1. 타깃 확정 (설명으로 받은 경우만)
`take_snapshot`으로 요소를 찾고, 그 요소의 안정적인 셀렉터나(예: id·고유 클래스) 또는 그 컴포넌트를
만드는 JS의 눈에 띄는 문자열을 정한다. 이미 셀렉터/심볼을 받았으면 건너뛴다.

### 2. 타깃이 든 번들 찾기

**CSS** — CSSOM을 훑어 규칙이 든 스타일시트의 `href`를 얻는다:
```js
() => {
  const hits = [];
  for (const ss of document.styleSheets) {
    let rules; try { rules = ss.cssRules; } catch (e) { continue; }
    if (!rules) continue;
    for (const r of rules) if ((r.cssText||'').includes('coupon-body'))   // ← 타깃 문자열
      hits.push(ss.href || '(inline)');
  }
  return [...new Set(hits)];
}
```
→ `optimizer_user.php?filename=…&type=css` 형태 URL이 나온다.

**JS** — JS 심볼은 CSSOM 같은 매핑이 없다. `<script src>` 중 옵티마이저 번들들을 모아 **본문을 fetch해 grep**한다:
```js
() => Array.from(document.querySelectorAll('script[src]'))
  .map(s => s.src)
  .filter(src => /optimizer(_user)?\.php/.test(src) && /type=js/.test(src));
```
그다음 각 번들을 `page.request.get(url)`로 받아 본문에 타깃 코드 문자열이 있는지 확인해 **해당 번들**을 특정한다.

> 통합 팁: CSS도 확실히 하려면 번들 본문을 직접 fetch해 grep하면 된다. `optimizer_user.php`(유저 파일)를
> 우선 본다 — 우리가 고칠 건 거의 항상 여기 있다. `optimizer.php`(Cafe24 기본)는 수정 대상이 아니다.

### 3. 번들 filename 디코드 → 소스 파일 목록
`scripts/decode_bundle.py`에 번들 URL(또는 filename 값)을 넘긴다:
```bash
python3 scripts/decode_bundle.py --user-only --urls '<optimizer_user.php URL 전체>'
```
출력: 번들에 묶인 유저 스킨 파일 경로들 + 추정 raw 경로. (인코딩상 하이픈까지 복원되나,
언더스코어 등 일부 특수문자는 어긋날 수 있으니 **후보**로 본다.)

### 4. 정확한 파일 확정 (raw fetch + grep)
목록에서 이름이 관련돼 보이는 후보를 골라, 몰 origin + 추정 경로로 **원본 파일을 직접 받아** 타깃을 grep한다:
```js
async (page) => {
  const cands = ['/css/module/product/first-improve-product-detail.css', /* … */];
  const out = [];
  for (const p of cands) {
    const r = await page.request.get('https://cloop.co.kr' + p);
    const t = r.ok() ? await r.text() : '';
    const i = t.indexOf('coupon-body');              // ← 타깃 문자열
    out.push({ file: p, status: r.status(), hit: i>-1,
               line: i>-1 ? t.slice(0,i).split('\n').length : null });
  }
  return out;
}
```
- 404가 나면 언더스코어/하이픈 변형(`detailoption` → `detail_option`)이나 디렉터리 관례를 바꿔 재시도한다.
- 히트한 파일 + 라인이 **정답**이다.

### 5. 보고
`<원본 파일 경로>:<라인>` 형태로 알려준다. 요청 시 번들에 묶인 전체 파일 목록도 제시한다.
저장소가 부분 미러라 그 파일이 로컬에 없을 수 있음을 명시하고, 있으면 로컬 경로로 매핑해준다.

## 주의사항 (전부 실측 기반)
- **옵티마이저 캐시:** 번들은 서버 캐시가 있어 배포 직후엔 옛 내용이 나올 수 있다. `filename`/`t=`가 바뀌어도
  본문이 stale일 수 있으니 시간을 두고 재확인.
- **optimizer_user vs optimizer:** 유저 수정 대상은 `optimizer_user.php`. `optimizer.php`(기본)는 건드릴 대상이 아니다.
- **스킨 번호는 몰마다 다르다:** 디코드 결과의 `sdedesign/<skin>/`에서 스킨 폴더명이 드러난다(PC=`skin3`, 모바일=`mobile31` 등은 예시).
- **raw 파일이 직접 안 열릴 때:** 몰에 따라 개별 파일 직링크가 막힐 수 있다. 그때는 번들 본문 grep으로 위치/오프셋만 확인하고,
  파일명은 디코드 목록으로 특정한다.
- **인코딩 불완전성:** 디코더는 하이픈은 복원하지만 언더스코어 등은 놓칠 수 있다 → 반드시 fetch+grep으로 확정.

## 리소스
- `scripts/decode_bundle.py` — 번들 `filename` 파라미터를 소스 파일 목록으로 디코드. `--user-only`(스킨 파일만),
  `--urls`(추정 raw 경로 동시 출력). 인자는 filename 값 또는 optimizer URL 전체 둘 다 허용.
