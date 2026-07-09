# WebKit pitfall catalog

Each entry: grep pattern → verdict criteria (what makes a hit a real pitfall) → fix → confidence tier.

Severity ordering: §1 kills entire scripts, §2–3 break layout invisibly, the rest degrade UX. Scan all; prioritize findings in this order.

## 1. Regex lookbehind — script killer [report-only]

- **Grep:** `(?<=` and `(?<!` in js files.
- **Verdict:** Safari < 16.4 throws `SyntaxError` at *parse time* — the entire script file dies, not just the one regex. Any hit in code served to Safari is confirmed.
- **Fix:** rewrite without lookbehind (capture group + index math). Rewrites change matching logic — report with a suggested rewrite instead of applying.

## 2. SVG width ignored in shrink-to-fit flex containers [auto-fix]

- **Grep:** css rules targeting `svg` that set `width:` without `min-width:`.
- **Verdict:** confirmed when the svg sits inside a container that is (a) content-sized — `position: fixed/absolute` without explicit width, or `width: fit-content/max-content` — and (b) `display: flex`. WebKit computes the container's shrink-to-fit width treating the svg's CSS width as 0, then renders the svg at full size, so text eats the right padding. Computed styles look correct; only rects reveal it. (Origin: LABNOSH added-toast, 2026-07.)
- **Fix:** add `min-width` equal to the width (and `min-height` if height is set and the axis matters). Adding min-width equal to an existing width is side-effect-free.

## 3. 100vh includes the iOS address bar [auto-fix]

- **Grep:** `100vh` in css.
- **Verdict:** confirmed on full-screen fixed elements or bottom-anchored UI on mobile — the element extends under the collapsed address bar, hiding bottom content. Desktop-only usage (inside `min-width` media queries) is a false positive.
- **Fix:** add `height: 100dvh;` on the line after the `100vh` declaration (same property). Older Safari ignores the unknown unit and keeps the vh fallback — a safe cascade.

## 4. Date string parsing [auto-fix for literals, report-only for variables]

- **Grep:** `new Date(` and `Date.parse(` in js.
- **Verdict:** confirmed when the argument is a non-ISO string: `"YYYY-MM-DD HH:MM"` (hyphen date + space separator) returns `Invalid Date` in Safari. Numeric args, `new Date()` with no args, and strict ISO (`T` separator) are false positives. Variable arguments: undecidable from static analysis — report with the call site.
- **Fix (literals):** convert to ISO with `T` separator, or `new Date(y, m-1, d, …)` numeric form.

## 5. Input font-size under 16px triggers iOS auto-zoom [report-only]

- **Grep:** `font-size` declarations under 16px on `input`, `select`, `textarea` selectors (check inherited sizes too when a form control's selector hits).
- **Verdict:** confirmed when the control is reachable on mobile viewports. iOS zooms the page on focus.
- **Fix:** 16px font-size on the control (design decision — reported, not applied).

## 6. Missing -webkit- prefixes [auto-fix]

- **Grep:** `backdrop-filter`, `user-select`, `background-clip: text`, `mask-image`/`mask:`, `position: sticky` in css — flag when the `-webkit-` twin is absent from the same rule.
- **Verdict:** `backdrop-filter` still requires the prefix in current Safari; the others matter for the older-Safari range this repo already prefixes for. A rule that already has the prefixed twin is a false positive.
- **Fix:** insert the `-webkit-` declaration on the line before the standard one, matching the repo's existing prefix style.

## 7. Scroll chaining from drawers/modals [report-only]

- **Grep:** `overscroll-behavior` in css; also flag scrollable overlays (`overflow-y: auto` inside `position: fixed` containers) that have *no* overscroll handling at all.
- **Verdict:** `overscroll-behavior` is Safari 16+; on older Safari the page behind a drawer scrolls when the drawer's list hits its end. Confirmed when a fixed overlay contains its own scroll area.
- **Fix:** body scroll lock (`position: fixed` on body while open) — behavioral change, so report.

## 8. position: sticky silently dead under overflow ancestors [report-only]

- **Grep:** `position: sticky` in css.
- **Verdict:** confirmed when an ancestor between the sticky element and its scroll container has `overflow: hidden/auto` — sticky does nothing, in Safari the symptom often differs from Chrome. Requires reading the DOM structure; undecidable hits are reported as "check ancestry".
- **Fix:** restructure or move the overflow — layout decision, report.

## 9. border-radius + overflow: hidden + transform clipping [report-only]

- **Grep:** rules combining `border-radius` and `overflow: hidden` where the same element or a child uses `transform`/`transition` on transform.
- **Verdict:** WebKit sometimes fails to clip children to the rounded corners during/after transforms. Cannot be confirmed statically — report as "verify visually in Safari".
- **Fix:** `isolation: isolate` or `z-index: 0` on the clipping element.

## 10. Newer JS APIs beyond the support floor [report-only]

- **Grep:** `structuredClone(`, `.at(`, `Array.fromAsync`, `requestIdleCallback` in js.
- **Verdict:** depends on the project's Safari support floor — `structuredClone` 15.4+, `.at()` 15.4+, `requestIdleCallback` unsupported before 18. Report with the required version so the user can judge against their floor.
- **Fix:** polyfill or rewrite per item — support-range decision, report.
