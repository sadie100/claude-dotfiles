# 스크린샷 캡처·업로드 절차

운영 매뉴얼의 스크린샷은 **표준 데모몰**(itadmin001, `https://itadmin001.cafe24.com/skin-skin4/`)에서 찍는다. 해당 영역에 빨간 박스를 그려 "이 설정이 이 화면"임을 표시하는 것이 목적이다.

## 브라우저 (chrome-devtools-shared)

- 공유 크롬에 **내 탭을 새로 열어** 작업한다(`new_page`). 다른 탭은 건드리지 않는다.
- 뷰포트는 `emulate`로만: PC `1440x900x1`, 모바일 `390x844x2,mobile,touch`. `resize_page` 금지(공유 크롬 OS 창을 망가뜨림).
- URL에 캐시 우회 쿼리(`?x=<임의값>`)를 붙인다 — 카페24 서버 캐시가 구렌더를 섞어 준다.
- 데모몰 상품번호는 클룹과 다르다. 골라담기 데모 상품 등은 `mall/itadmin001/setup.js`에서 번호를 확인하고 들어간다(setup.js의 링크 값은 클룹 번호라 데모몰에서 404가 난다).

## 빨간 박스 오버레이

원리: 대상 요소의 `getBoundingClientRect()` 위치에 `border: 3px solid #FF0000` div를 겹쳐 그린 뒤 뷰포트 스크린샷.

```javascript
// evaluate_script로 실행. sticky/fixed 요소(헤더, 상세 우측 구매 패널)가 있으므로
// 반드시 "스크롤을 먼저 하고 → 그 자리에서 마킹"한다. 마킹 후 스크롤하면 박스가 어긋난다.
() => {
  window.scrollTo({top: 0});            // 또는 el.scrollIntoView({block:'center'}) 후 300ms 대기
  document.querySelectorAll('.__redbox').forEach(e => e.remove());
  const el = document.querySelector('<셀렉터>');
  const r = el.getBoundingClientRect();
  const d = document.createElement('div');
  d.className = '__redbox';
  d.style.cssText = 'position:absolute;border:3px solid #FF0000;border-radius:4px;' +
    'z-index:2147483647;pointer-events:none;' +
    'left:' + (r.left + window.scrollX - 4) + 'px;top:' + (r.top + window.scrollY - 4) + 'px;' +
    'width:' + (r.width + 8) + 'px;height:' + (r.height + 8) + 'px;';
  document.body.appendChild(d);
}
```

- 모달·전체화면 패널처럼 뷰포트에 고정된 대상은 `position:fixed` + rect 좌표(스크롤 보정 없이)로 그린다.
- 셀렉터는 표준 스킨의 `.std-*` 클래스에서 찾는다. 못 찾으면 `[class*="std-"]` 전수 나열로 후보를 뽑는다.
- 요소가 `w:0`이면 숨김 상태다(fail-open이거나 설정 꺼짐). 설정으로 꺼진 UI를 문서화해야 하면 켜짐 상태 클래스를 강제로 붙여 연출한다(예: PC 카테고리 버튼은 `.std-header`에 `is-catbtn-on-pc` 추가). 연출한 캡처는 문서 캡션에 "설명을 위해 켠 상태"라고 명시한다.

## 저장 → 업로드 → 삽입

1. `take_screenshot`의 `filePath`는 **워크스페이스 루트 안**이어야 한다(밖은 Access denied). 레포 안 임시 폴더(예: `<repo>/.tmp-manual-shots/`)에 저장하고 **작업 끝나면 폴더째 삭제**한다(git 오염 방지).
2. 캡처 직후 Read로 이미지를 열어 박스 위치를 눈으로 검증한다. 어긋났으면 재촬영(대부분 sticky 스크롤 순서 문제).
3. 노션 업로드: 이미지마다 `notion-create-file-upload(filename)` → 반환된 `upload_url`/`authorization` 헤더로 curl POST:
   ```bash
   curl -s -X POST "<upload_url>" -H "authorization: Bearer <token>" -F "file=@<파일>" \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['markdown_source'])"
   ```
   출력된 `file-upload://<id>`를 페이지 마크다운에 `![캡션 (빨간 박스)](file-upload://<id>)`로 삽입한다.
4. 캡션에는 설정 키 이름과 화면 위치를 함께 쓴다 — 예: `pc.panel — 버튼 클릭 시 드롭다운 목록 (빨간 박스)`.
5. 한 번 삽입한 이미지 블록은 MCP로 삭제·이동할 수 없다(URL 매칭 불가 — SKILL.md §5). 캡션만은 `![캡션]` 부분 매칭으로 고칠 수 있으므로, 교체·이동 시에는 새로 업로드해 넣고 옛 이미지 캡션에 `[제거 필요] ` 프리픽스를 붙여 사용자가 UI에서 지우게 한다(같은 캡션이 여럿이면 첫 번째에만 붙으니 순서 주의). 원본이 필요하면 fetch 직후 서명 URL로 다운로드해 두면 재업로드에 쓸 수 있다(유효 5분).
