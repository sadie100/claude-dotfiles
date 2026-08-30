# 도메인 → 서비스 대조표

실제 자사몰 분석(클룹, 에이템/한끼통살)에서 확인된 도메인들. 새 몰에서 이 표에 없는 도메인이 나오면 조사 후 여기에 추가할 것.

## 기능성 SaaS

| 도메인 | 서비스 | 비고 |
|---|---|---|
| `widgets.cre.ma`, `review*.cre.ma` | 크리마 (리뷰) | init.js의 경로가 몰 코드 |
| `cdn.channel.io` | 채널톡 | `channelPluginSettings`의 plugin_id |
| `cdn.notifly.tech` | Notifly (웹푸시) | 서비스워커 파일(`notifly-service-worker.js`)만 남는 경우 잔재 의심 |
| `cro.myshp.us` | 업셀 위젯 | `<upsell-widget-*>` 커스텀 엘리먼트 |
| `wizmade.link` | 위즈메이드/링크메이드 (인플루언서 제휴) | iframe 직삽입 |
| `live24.app`, `l24wiget-*.web.app` | Live24/쇼츠24 | 전용 플레이어 페이지 |
| `is.digit-point-app.com` | 디지트포인트 (이벤트 위젯) | |
| `developers.kakao.com/sdk` | Kakao JS SDK (공유) | `pf.kakao.com/*`은 카카오채널 단순 링크(SDK 아님) |
| `shk`/`payshook` 류 | 결제슉 | jquery의 `cssHooks`가 오탐되니 주의 |

## 마케팅/트래킹

| 도메인 | 서비스 |
|---|---|
| `wcs.naver.net` | 네이버 프리미엄 로그분석 |
| `www.googletagmanager.com` | GTM/GA4 (로더는 대개 관리자 주입) |
| `connect.facebook.net` | Meta Pixel |
| `analytics.tiktok.com` | TikTok Pixel (`ttq.track`) |
| `api.aedi.ai`, `cv.aedi.ai` | AEDI/AiSUM |
| `script.ifdo.co.kr`, `img.ifdo.co.kr` | IFDO (아이투아이, `_NB_*` 변수) |
| `tenping.kr` | 텐핑 (CPS 제휴) |
| `www.clarity.ms` | MS Clarity |
| `cdn-aitg.widerplanet.com` | 와이더플래닛 |
| `cdn.taboola.com` | Taboola (`_tfa.push`) |
| `t1.daumcdn.net/adfit/kp.js` | 카카오 픽셀 |
| `cdn.megadata.co.kr` | Enliple/PlayD TERA (`_LA`, `sendConv`) |
| `server.*.bigin.io`, `sdk.bigin.io` | Bigin CRM (`_b_g_e_b_f` 큐) |
| `rum.beusable.net` | 뷰저블 |
| `*.acecounter.com`, `*.nsm-corp.com` | 에이스카운터 / NSM |
| `rs.pangx2.com` | RE:LOAD(팡팡, 이탈방지) |
| `static.hotjar.com` | Hotjar |
| `pixel.mathtag.com` | MediaMath |
| `googleads`/`AW-*`/`UA-*` | Google Ads / 구 UA |

## 카페24 표준 (플러그인 아님)

- `img.echosting.cafe24.com`, `img.cafe24.com` — 카페24 정적 리소스
- `cafe24img.poxo.com`, `optimizer.poxo.com` — 이미지호스팅/HTML 최적화
- `iniweb.inicis.com`, `partner.kcp.co.kr`, `www.payco.com` — 표준 PG/에스크로 링크
- `doortodoor.co.kr`, `service.epost.go.kr` — 배송조회 링크
- `EC_FRONT_JS_CONFIG_MANAGE`, `paymentOrder.js` — 카페24 기본 번들

## 커스텀 인프라 패턴 (몰마다 다름 — 형태로 식별)

- 자체 백엔드 도메인 (예: `atemplus.kr/admin/*` API) — 관리자(CMS)와 URL prefix가 같으면 그 CMS가 공급자
- `*.cloudfront.net`, `*.execute-api.*.amazonaws.com` — AWS 배포 설정파일/API
- `gcube.decodelab.co.kr` 류 프록시 — `?url=` 파라미터로 다른 몰 데이터를 중계(CORS 우회)
- 몰 루트 `/json/*.json` — 관리자가 생성해 올리는 정적 데이터 레이어(레포에 없어도 라이브에 존재)
- 형제몰 `*.cafe24.com/<이름>/api/*.php` — 자체 PHP 백엔드(레거시 흔함)
