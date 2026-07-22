---
name: cafe24-data-source-survey
description: Use when surveying across the company's Cafe24 malls (자사몰) how a specific piece of page data is sourced/rendered — e.g. "자사몰들에서 X가 어디서 나오는지 조사해서 문서화해줘", "몰별로 데이터 소스 비교", "이 데이터 활용양상 정리". Traces each mall's live page to its Cafe24 source (module/variable, admin editor field, skin JS, third-party app) and records the findings as a category in the 자사몰-데이터-활용양상 doc.
---

# cafe24-data-source-survey

자사몰들이 **같은 정보를 각자 어떤 카페24 데이터 소스로 관리·렌더하는지** 횡단 조사해 문서로 남긴다.
목적: 표준 스킨이 어떤 소스를 채택해야 이식 비용이 최소인지 판단할 근거 축적.

**REQUIRED SUB-SKILL:** 몰별 역추적은 `cafe24-find-source` 워크플로우를 쓴다 (공유 디버깅 크롬 규칙 포함 — 내가 연 탭에서만 작업).

## 자사몰 로스터

| 몰 | 홈 URL | 로컬 스킨 소스 |
|---|---|---|
| 한끼통살 | https://hankkitongsal.com/ | `ftp/atem/` |
| 랩노쉬 | https://labnosh.com/ | `ftp/labnosh/` |
| 그로서리서울 | https://groceryseoul.com/ | 없음 (`ftp/groceryseoul`은 sftp 설정뿐) |
| 메디리즈 | https://medileeds.com/ | `medileeds-cafe24/` |
| BRAYE | https://braye.co.kr/ | 없음 |
| 원데이원볼 | https://oneday1ball.com/ | 없음 |
| 엑쎄라피 | https://exerapy.co.kr/ | `exerapy-cafe24/` |
| 클룹 | https://cloop.co.kr/ | `ftp/cloop/` |

로컬 소스 루트: `/Users/sadie100/dev/works/cafe24/`. 미러는 부분/구버전일 수 있으니 라이브 실측과 대조해 쓴다.

## 절차

1. **조사 대상 확정.** 사용자 요청에서 (a) 어떤 데이터·화면 요소인지 (b) 어떤 페이지 타입인지(상품상세/메인/장바구니 등) (c) 대상 몰(명시 없으면 로스터 전체)을 확정한다. 사용자가 세부 URL을 줬으면 그걸 쓰고, 아니면 홈에서 해당 페이지로 직접 이동해 찾는다(상품상세면 아무 상품이나).
2. **몰별 역추적.** 몰마다: 페이지를 열고 타깃 텍스트/요소를 DOM에서 찾아 조상 체인을 확인한 뒤 소스를 판정한다.
   - `xans-*` 클래스 → 카페24 모듈·변수 (`cafe24-smart-design` 레퍼런스로 변수 특정)
   - 원문 HTML을 유니크 쿼리로 fetch해 **서버 렌더 vs JS 주입** 판별. 서버 렌더인데 DOM과 다르면 스킨 JS 후처리(하이브리드)를 의심하고 JS까지 추적한다
   - 로컬 미러가 있으면 스킨 소스에서 변수·마크업을 `파일:라인`으로 확정
   - JS 주입이면 주입 스크립트(스킨 JS / `appfiles` 앱 스크립트)를 특정
   - 완료 기준: **몰마다 "소스 유형 + 근거(DOM 체인, 파일:라인 또는 스크립트)"가 나오거나, "미확정 + 이유"가 기록된다.** 접속 불가·요소 없음도 그대로 기록하고 넘어간다.
3. **소스 유형 분류.** 각 몰을 다음 중 하나(혼합이면 하이브리드로 명기)로 분류: ① 카페24 모듈·변수(표준 용도) ② 관리자 에디터 필드 전용/轉用(사이즈가이드 설명, 요약설명 등) ③ 스킨 JS 하드코딩 ④ 제3자 앱 콘텐츠.
4. **문서화.** `docs/자사몰-데이터-활용양상.md`가 현재 저장소에 있으면 거기에 `##` 카테고리 하나를 추가한다 — **형식은 문서의 기존 카테고리(몰별 표 → 몰별 세부 → 표준 스킨 관점 정리)를 그대로 따르고 조사일을 명기**한다. 문서 경로가 없는 프로젝트면 같은 구조로 채팅에 답한다. 완료 기준: 요청된 몰 전부가 몰별 표에 등장한다.
5. **정리.** 이 조사에서 내가 연 브라우저 탭을 모두 닫는다.

## 함정 (실측 기반)

- **캐시**: 카페24는 URL 키 캐시라 원문 fetch에 유니크 쿼리(`?x=<ts>`) 필수.
- **UA 스킨 분기**: 데스크톱 크롬은 PC 스킨. 모바일 스킨 조사면 모바일 UA로.
- **하이브리드**: 서버 렌더 콘텐츠를 스킨 JS가 prepend/append/치환하는 몰이 있다(한끼통살 사례). DOM만 보고 소스를 단정하지 말고 원문과 diff한다.
- **기본 모듈 숨김 관례**: `product_detaildesign` 같은 기본 모듈이 렌더는 되는데 CSS/인라인으로 숨겨져 있고 실노출은 다른 소스인 몰이 많다. "보이는 것"과 "존재하는 것"을 구분해 기록한다.
