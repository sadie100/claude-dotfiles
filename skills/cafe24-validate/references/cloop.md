# 클룹(cloop) 전용 체크 — 골라담기 방어 로직 상태

클룹은 골라담기(커스텀옵션) 상품에서 오주문을 막는 방어 로직이 PC/모바일 양쪽에 배포되어 있다 (설계: 클룹 저장소 `docs/클룹-이식-분석.md`). 순회 시 공통 점검에 더해 아래를 확인한다.

## 골라담기 상품 vs 일반 상품

- 골라담기 상품: `#flavor-config` 엘리먼트 존재, 또는 옵션명에 variant 패턴(`48개입#1`/`48개입#2`처럼 `[#_]숫자`만 다른 동일 구성 2개 이상)
- 순회 대상에 **골라담기 상품과 일반 상품을 반드시 둘 다** 포함할 것. 골라담기는 방어가 정상 해제됐는지, 일반 상품은 방어가 오탐 개입하지 않는지가 각각의 확인 포인트다.
- 대표 상품 (2026-07 기준): 골라담기 230(애사비소다 12종)·489(체험팩), 일반 400(원더팝)·179(바이탈레몬). 상품 구성이 바뀔 수 있으니 목록에서 재확인.

## 상태 점검 스니펫

PC 스킨용 (`browser_evaluate`):

```js
() => {
  var t = document.querySelector("table.xans-product-option");
  var cs = t ? getComputedStyle(t) : null;
  var lis = document.querySelectorAll("ul.ec-product-button li");
  var variantCount = 0;
  lis.forEach(function(li){ if(/[#_]\d+/.test(li.getAttribute("title")||li.textContent||"")) variantCount++; });
  return {
    flavorConfig: !!document.getElementById("flavor-config"),
    variantOptions: variantCount + "/" + lis.length,
    ready: window.__customOptionReady === true,
    pendingClass: document.documentElement.classList.contains("cloop-copt-pending"),
    overlayVisible: (function(){var el=document.querySelector(".cloop-copt-loading"); return el ? getComputedStyle(el).display : "absent";})(),
    customUiShown: (function(){var el=document.querySelector(".custom-option-ui"); return el ? el.offsetHeight > 0 : false;})(),
    tierCards: document.querySelectorAll(".tier-card").length,
    nativeHidden: cs ? (cs.display === "none" || (cs.position === "absolute" && cs.clip !== "auto")) : "no-table",
    submitGuarded: typeof window.product_submit === "function" ? window.product_submit.__cloopGuarded === true : "no-fn",
    detect: typeof window.__customOptionDetectIssues === "function" ? window.__customOptionDetectIssues() : "no-fn"
  };
}
```

모바일 스킨용 — 네이티브 옵션의 sr-only가 테이블이 아니라 래퍼에 걸리고, 커스텀 UI 마커가 다르다:

```js
() => {
  var wrap = document.querySelector(".ec-base-table.typeWrite.gClearCell.gClearBorder");
  var cs = wrap ? getComputedStyle(wrap) : null;
  var layer = document.getElementById("product_detail_option_layer");
  return {
    moTemplate: !!layer && document.querySelectorAll(".prd-action-btn").length > 0,
    flavorConfig: !!document.getElementById("flavor-config"),
    ready: window.__customOptionReady === true,
    pendingClass: document.documentElement.classList.contains("cloop-copt-pending"),
    overlayVisible: (function(){var el=document.querySelector(".cloop-copt-loading"); return el ? getComputedStyle(el).display : "absent";})(),
    layerActive: layer ? layer.classList.contains("custom-option-active") : "no-layer",
    tierCards: document.querySelectorAll(".tier-card").length,
    nativeHidden: cs ? (cs.display === "none" || (cs.position === "absolute" && cs.clip !== "auto")) : "no-wrap",
    submitGuarded: typeof window.product_submit === "function" ? window.product_submit.__cloopGuarded === true : "no-fn",
    detect: typeof window.__customOptionDetectIssues === "function" ? window.__customOptionDetectIssues() : "no-fn"
  };
}
```

## 판정 기준

**골라담기 상품 (정상):**

| 항목 | 기대값 | 어긋나면 의미 |
| --- | --- | --- |
| `ready` | `true` | 초기화 실패 — config 깨짐/예외. 잠금이 걸려 있어야 정상적 실패 |
| `pendingClass` / `overlayVisible` | `false` / `"absent"` (또는 `none`) | `true`/`flex`면 잠금이 안 풀림 = 초기화 실패 상태 |
| `customUiShown`(PC) / `layerActive`(mo) + `tierCards ≥ 1` | 커스텀 UI 표시 | 커스텀 UI 미렌더 |
| `nativeHidden` | `true` | 네이티브 옵션 노출 = CSS 미적용/배포 누락 |
| `submitGuarded` | `true` | 구매 검증 래핑 누락 — 오주문 방어 꺼짐 (심각) |
| `detect` | `[]` | 이슈 코드가 나오면 그 코드가 원인을 말해줌 (notReady/inProgress/nativeRow/nativeOptionVisible/emptyAddOption) |

**일반 상품 (정상 = 개입 0):** `flavorConfig=false`, `pendingClass=false`, `overlayVisible="absent"`, `submitGuarded=false`, `detect=[]`. 여기서 잠금·래핑이 걸려 있으면 **variant 패턴 오탐** — 옵션명을 확인할 것.

## 배포 조합 사고 판별 (실제 있었던 사고)

파일명이 PC/모바일 양쪽 다 같아서(`product-detail.html` 등) **엉뚱한 환경의 파일이 배포되는 사고**가 실제로 발생했다. 골라담기 상품이 전부 잠금 상태(`ready=false` + 오버레이)로 나오면 방어 로직 버그로 단정하지 말고 먼저 배포 조합을 의심한다:

- 모바일 스킨인데 PC 템플릿이 올라간 경우: `moTemplate=false` (모달 `#product_detail_option_layer` 없음), 페이지에 PC 마커(`bsPrdDetail detail-container`, `detailLeft`, `.infoArea`) 존재
- PC 스킨인데 mo 템플릿: 반대로 `.infoArea` 없음 + `prd-action-btn` 존재
- JS 버전 판별: `String(window.__customOptionDetectIssues)`에 `"ec-base-table"`이 포함되면 mo판, 없으면 PC판

조합이 어긋나 있으면 순회를 중단하고 "어느 파일이 어느 스킨에 잘못 올라갔는지"를 먼저 보고한다.

## 알려진 기존 콘솔 에러 (이번 변경과 무관)

- `ERR_UNKNOWN_URL_SCHEME` — 트래킹 스크립트의 앱 스킴 리소스 차단
- `ReferenceError: $order_count is not defined` — 스킨 인라인 스크립트의 카페24 템플릿 변수 미치환 (기존 문제)
