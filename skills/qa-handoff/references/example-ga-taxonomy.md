# 한끼통살 GA4 택소노미 QA 인계

한끼통살 테스트 스킨에 이식한 GA4 택소노미 엔진에서 아직 실측하지 않은 케이스를 QA 에이전트에게 넘기는 문서입니다. 아래 "지금 상황"으로 전제를 확인한 뒤 "테스트할 것"을 순서대로 실측하고, 결과는 [GA-택소노미-테스트케이스.md](GA-택소노미-테스트케이스.md)의 해당 행에 적어 주세요. 이미 끝난 케이스와 고친 문제의 원인도 그 문서에 있으니, 같은 케이스를 다시 재지 않아도 됩니다. 2026-10-16 기준입니다.

## 지금 상황

브라우저에서 gtag로 나가는 이벤트는 2026-10-15에 PC와 MO 테스트 스킨에서 실측을 마쳤습니다. 남은 것은 서버를 거치는 `purchase`와, 계정이 있어야 하는 로그인 케이스입니다.

`purchase`는 브라우저가 gtag로 보내지 않습니다. 주문완료 화면에서 엔진(`analytics/events/purchase.js`)이 분석 람다에 GET 요청을 하나 보내고, 람다가 카페24 Admin API로 주문을 조회해 Measurement Protocol로 GA4에 보냅니다. 이 경로에 필요한 준비는 아래 표와 같습니다.

| 준비 | 상태 |
|---|---|
| standard-app 설치와 토큰(`auth_cafe24` labnosh 행) | 완료(사용자가 앱 설치, 2026-10-16) |
| 접근 시크릿 `allowedDomainKeywords`에 `labnosh` | 완료(사용자 확인, 2026-10-16) |
| GA4 Measurement Protocol API 비밀번호 생성 | 완료(사용자가 GA4 관리자에서 생성, 2026-10-16) |
| 그 비밀번호를 람다 시크릿(`GA4_MP_SECRET_ARN`)에 `labnosh` 항목으로 등록 | 미확인. 실측 전에 사용자에게 확인 |
| 스킨 쪽 설정 `api/api.config.js`의 `StdAnalyticsApiConfig` | 완료(PC·MO 테스트 스킨, mallId `labnosh`) |

주문완료 페이지 `order/order_result.html`은 PC와 MO 모두 `layout/basic/layout.html`을 쓰므로 엔진이 이미 들어가 있습니다.

## 테스트 환경

| 항목 | 값 |
|---|---|
| PC 테스트 스킨 | https://labnosh.cafe24.com/skin-skin74/ |
| MO 테스트 스킨 | https://labnosh.cafe24.com/skin-mobile70/ |
| GA4 속성 | 표준화_한끼통살 (`G-B2VNZ22PH9`), DebugView |
| 분석 람다 요청 | `GET https://commerce-api.egnis.net/analytics/v1/labnosh/purchase?order_id=…&amount=…&client_id=…&session_id=…&debug=1` |

개발 스킨 경로로 열면 엔진 이벤트에 `debug_mode`가 붙고, 람다 요청에도 `debug=1`이 붙어 DebugView에서 볼 수 있습니다. MO는 PC UA가 아니라 DevTools `emulate`의 iPhone UA로 열어야 서버가 모바일 모드로 렌더합니다.

브라우저는 `chrome-devtools-shared` 서버의 공유 크롬을 씁니다. 회원 탭 하나와 비회원 탭 하나만 두고, 탭을 쓰기 전에 쿠키 `iscache=F`로 회원 여부를 확인합니다. 창 크기는 `resize_page` 대신 `emulate`로 바꾸고, 쓴 탭은 닫지 않습니다. 자세한 규칙은 `dev/works/CLAUDE.md`에 있습니다.

## 테스트할 것

### purchase

| 케이스 | 조건 | 확인할 것 |
|---|---|---|
| 비회원 실주문 | PC 테스트 스킨, 상품 1개, 무통장 입금 | 아래 확인 항목 전부 |
| 회원 실주문 | PC 테스트 스킨, 무통장 입금, 회원 로그인 | 위와 같고, 람다 요청에 `user_id`가 실리는지 |
| MO 실주문 | MO 테스트 스킨, iPhone UA, 비회원, 무통장 입금 | 위와 같음 |
| 골라담기 상품 주문 | 3176(골라담기) 30개입 포함, 비회원 | `items`의 `item_variant`에 맛 원문이 실리는지, `item_category`가 붙는지 |
| 새로고침 중복 | 주문완료 화면을 새로고침 | 람다 요청이 다시 나가지 않는지(`localStorage` `std_analytics_purchase_sent`에 주문번호가 있는지) |
| 주문완료 `page_view` | 위 주문 중 하나 | `page_type` order_complete로 1회 나가는지 |

주문 한 건마다 다음을 확인합니다.

- 주문완료 화면에서 분석 람다 요청이 1회 나가고 응답이 200인지 봅니다. 403이면 접근 시크릿, 5xx면 람다 쪽 문제이므로 응답 본문과 함께 사용자에게 알립니다.
- DebugView에 `purchase`가 도착하는지 봅니다. 람다가 Measurement Protocol로 보내므로 수 초에서 수십 초 늦게 도착할 수 있습니다.
- `transaction_id`가 주문번호와 같고, `value`가 결제 금액과 같은지 봅니다.
- `items`의 행 수, `item_id`, `price`, `quantity`가 주문 내역과 같은지, `item_brand`(한끼통살)와 `item_category`가 붙는지 봅니다.
- 같은 주문의 `purchase`가 GTM 속성(`G-JTGRJ0DGRZ`)이 아니라 `G-B2VNZ22PH9`에만 도착하는지 봅니다. GTM은 기존대로 자기 속성에 따로 보내므로 그쪽 `purchase`는 원래 있는 것입니다.

람다 요청이 아예 나가지 않으면 `purchase.js` 머리 주석의 ①~⑥ 단계 중 어디서 멈췄는지 콘솔에서 확인합니다. 코어 전역 `CAFE24.FRONT_EXTERNAL_SCRIPT_VARIABLE_DATA`의 `order_id`, `payed_amount`는 표준안에서 클룹 결제슉 주문완료로만 실측했고, 한끼통살 기본 주문완료에서는 처음 재는 값입니다.

### 로그인

| 케이스 | 조건 | 확인할 것 |
|---|---|---|
| 폼 로그인 성공 | 사용자의 labnosh 계정, PC와 MO | `login` 1회, `method` cafe24, `user_id`가 실리는지 |
| 로그인 뒤 회원 렌더 | 위 로그인 직후 메인, 상세 | 이후 이벤트에 `user_id`가 계속 실리는지 |
| 로그인 실패 | 틀린 비밀번호 | `login`이 나가지 않는지 |
| 네이버 로그인 | 사용자 계정이 네이버와 연결돼 있을 때만 | `login` 1회, `method` naver |

## 주의할 것

- 실주문은 사용자에게 먼저 알리고 넣습니다. 테스트 주문은 끝난 뒤 사용자가 관리자에서 취소하므로, 넣은 주문번호를 모두 기록해 둡니다.
- 회원 로그인은 사용자가 직접 합니다. labnosh 테스트 계정이 따로 없어서 사용자의 기존 계정을 쓰기 때문입니다. 비밀번호를 입력하거나 저장하지 않습니다.
- 주문서에 넣는 이름, 연락처, 주소는 테스트임을 알 수 있는 값으로 채웁니다.
- 실제 신규 가입(`sign_up`)은 이번 범위가 아닙니다. 일반 가입은 KCP 휴대폰 본인인증이 필수이고 사용자 번호는 이미 가입돼 있습니다.
- CRM UTM(`crm_external`), 매핑 표의 `오리지널 *10` 분류 누락, 운영 경로의 `debug_mode`도 이번 범위가 아닙니다. 각각 마케팅, 인트라넷 담당, 운영 스킨 이식을 기다립니다.
- 스킨 파일을 고쳐야 하는 문제가 나오면 고치지 말고 원인과 함께 보고합니다. FTP 업로드는 사용자가 합니다.

## 결과 기록

테스트케이스 문서의 `purchase` 절과 `login` 절의 해당 행에 상태와 결과를 적고, 맨 위 "요약" 표의 숫자를 맞춥니다. 실측 시각(DebugView 도착 시각)과 주문번호를 결과 열에 남겨 주세요. 끝나면 [GA-택소노미-이식-남은사항.md](GA-택소노미-이식-남은사항.md)의 "진행 상태" 문단에 purchase 확인 결과를 한 문장으로 더합니다.
