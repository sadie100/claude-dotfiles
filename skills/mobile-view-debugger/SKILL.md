---
name: mobile-view-debugger
description: >
  모바일 뷰에서 UI 문제점을 탐색하고 진단하는 스킬.
  Chrome DevTools MCP를 사용하여 모바일 디바이스 에뮬레이션, 스크린샷 촬영, DOM/CSS 분석을 수행한다.
  레이아웃 깨짐, 가로 오버플로우, 잘린 텍스트, 작은 터치 타겟, 반응형 이미지 문제 등
  모바일에서 흔히 발생하는 UI 문제를 자동으로 감지하고 리포트한다.
  사용 시점: "모바일에서 이상하게 나와", "모바일 뷰 확인해줘", "반응형 깨졌어",
  "모바일 레이아웃 점검", "스마트폰에서 UI 확인" 등 모바일 관련 UI 디버깅 요청 시 트리거.
  인자로 URL을 받거나, 현재 프로젝트의 로컬 서버 주소를 사용한다.
---

# Mobile View Debugger

모바일 뷰포트에서 웹 페이지의 UI 문제를 체계적으로 탐색하고 진단한다.

## Workflow

### 1. 페이지 접속 및 모바일 에뮬레이션

URL이 인자로 주어지지 않으면 사용자에게 URL을 물어본다.

`chrome-devtools__navigate_page`로 페이지에 접속한 뒤, `chrome-devtools__emulate`로 모바일 뷰포트를 설정한다.

기본 디바이스: **iPhone 14** (390x844, DPR 3). 사용자가 특정 디바이스를 요청하면 [references/mobile-checklist.md](references/mobile-checklist.md)의 디바이스 목록을 참고하여 변경한다.

```
emulate → width: 390, height: 844, deviceScaleFactor: 3, mobile: true
```

### 2. 스크린샷 촬영

`chrome-devtools__take_screenshot`으로 현재 상태의 전체 페이지 스크린샷을 촬영한다. 이 스크린샷을 직접 확인하여 시각적으로 드러나는 문제를 먼저 파악한다.

### 3. 자동 진단 실행

[references/mobile-checklist.md](references/mobile-checklist.md)의 JS 스니펫들을 `chrome-devtools__evaluate_script`로 실행하여 문제를 자동 감지한다. 아래 순서로 진행:

1. **Viewport meta tag** 확인 — 누락 시 치명적
2. **Horizontal overflow** — 가로 스크롤 발생 요소 탐지
3. **Fixed width elements** — 뷰포트 초과 고정 너비 요소
4. **Text overflow / clipping** — 잘리거나 넘치는 텍스트
5. **Font size < 12px** — 읽기 어려운 작은 텍스트
6. **Touch target < 44px** — 탭하기 어려운 작은 인터랙티브 요소
7. **Elements too close to edge** — 화면 가장자리에 붙은 콘텐츠
8. **Non-responsive images** — max-width 미설정 이미지
9. **Oversized images** — 뷰포트보다 넓은 이미지

각 항목에서 발견된 요소가 있으면 결과를 기록한다.

### 4. 스크롤 탐색

페이지가 긴 경우 `chrome-devtools__evaluate_script`로 스크롤하며 추가 스크린샷을 촬영한다:

```js
window.scrollTo(0, window.innerHeight * N);  // N = 1, 2, 3...
```

페이지 하단까지 도달하거나 3~4회 스크롤 후 중단. 각 구간에서 시각적 문제를 확인한다.

### 5. 리포트 작성

발견된 문제를 아래 형식으로 정리하여 사용자에게 보고한다:

```
## 모바일 뷰 진단 결과

**디바이스**: iPhone 14 (390x844)
**URL**: {url}

### 심각도 높음 (즉시 수정 필요)
- [ ] {문제 설명} — `{selector/class}` — {구체적 수치}

### 심각도 중간 (개선 권장)
- [ ] {문제 설명} — `{selector/class}` — {구체적 수치}

### 심각도 낮음 (참고)
- [ ] {문제 설명} — `{selector/class}` — {구체적 수치}

### 스크린샷
{촬영된 스크린샷 첨부 또는 참조}
```

**심각도 기준:**
- **높음**: 가로 오버플로우, viewport meta 누락, 콘텐츠 잘림/안 보임, 레이아웃 완전 깨짐
- **중간**: 터치 타겟 너무 작음, 폰트 12px 미만, 이미지 반응형 미처리
- **낮음**: 가장자리 여백 부족, 미미한 정렬 어긋남

### 6. 추가 디바이스 테스트 (선택)

사용자가 요청하거나, 첫 디바이스에서 심각한 문제가 발견되면 다른 뷰포트(Galaxy S21 360px, iPhone SE 375px 등)로도 테스트하여 뷰포트 너비별 차이를 확인한다.

## Notes

- 진단 스크립트에서 결과가 빈 배열(`[]`)이면 해당 항목은 문제 없음으로 처리
- 스크린샷 시각 분석과 JS 자동 진단을 병행하여 놓치는 문제를 최소화
- 수정 범위를 짚어줄 때는 가능한 한 구체적인 CSS selector, class명, 파일 위치를 포함
