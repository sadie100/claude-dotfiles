# Mobile View Debugging Checklist

## Viewport & Layout

### Horizontal Overflow
- `document.documentElement.scrollWidth > document.documentElement.clientWidth`
- Find offending elements:
```js
[...document.querySelectorAll('*')].filter(el => {
  const rect = el.getBoundingClientRect();
  return rect.right > window.innerWidth || rect.left < 0;
}).map(el => ({
  tag: el.tagName,
  class: el.className,
  id: el.id,
  right: Math.round(el.getBoundingClientRect().right),
  width: Math.round(el.getBoundingClientRect().width),
  computedWidth: getComputedStyle(el).width
}))
```

### Fixed Width Elements
- Elements with hardcoded `width` in px exceeding viewport
```js
[...document.querySelectorAll('*')].filter(el => {
  const w = getComputedStyle(el).width;
  return w.endsWith('px') && parseFloat(w) > window.innerWidth;
}).map(el => ({ tag: el.tagName, class: el.className, width: getComputedStyle(el).width }))
```

### Viewport Meta Tag
```js
document.querySelector('meta[name="viewport"]')?.getAttribute('content') || 'MISSING'
```

## Text & Content

### Text Overflow / Clipping
```js
[...document.querySelectorAll('*')].filter(el => {
  const s = getComputedStyle(el);
  return (el.scrollWidth > el.clientWidth || el.scrollHeight > el.clientHeight)
    && s.overflow !== 'visible' && el.textContent.trim().length > 0
    && el.clientHeight > 0 && el.clientWidth > 0;
}).map(el => ({
  tag: el.tagName, class: el.className,
  scrollW: el.scrollWidth, clientW: el.clientWidth,
  scrollH: el.scrollHeight, clientH: el.clientHeight,
  text: el.textContent.trim().substring(0, 50),
  overflow: getComputedStyle(el).overflow
}))
```

### Font Size Too Small (< 12px)
```js
[...document.querySelectorAll('*')].filter(el => {
  const size = parseFloat(getComputedStyle(el).fontSize);
  return size < 12 && el.textContent.trim().length > 0
    && el.offsetWidth > 0 && el.offsetHeight > 0;
}).map(el => ({
  tag: el.tagName, class: el.className,
  fontSize: getComputedStyle(el).fontSize,
  text: el.textContent.trim().substring(0, 30)
}))
```

## Touch & Interaction

### Touch Target Size (< 44x44px, Apple HIG / WCAG)
```js
const interactive = 'a, button, input, select, textarea, [role="button"], [tabindex], [onclick]';
[...document.querySelectorAll(interactive)].filter(el => {
  const rect = el.getBoundingClientRect();
  return (rect.width < 44 || rect.height < 44)
    && rect.width > 0 && rect.height > 0;
}).map(el => ({
  tag: el.tagName, class: el.className,
  text: (el.textContent || el.getAttribute('aria-label') || '').trim().substring(0, 30),
  width: Math.round(el.getBoundingClientRect().width),
  height: Math.round(el.getBoundingClientRect().height)
}))
```

### Overlapping Clickable Elements
```js
(() => {
  const els = [...document.querySelectorAll('a, button, [role="button"], input, [onclick]')];
  const overlaps = [];
  for (let i = 0; i < els.length; i++) {
    const r1 = els[i].getBoundingClientRect();
    if (r1.width === 0) continue;
    for (let j = i + 1; j < els.length; j++) {
      const r2 = els[j].getBoundingClientRect();
      if (r2.width === 0) continue;
      if (r1.left < r2.right && r1.right > r2.left && r1.top < r2.bottom && r1.bottom > r2.top) {
        overlaps.push({
          el1: { tag: els[i].tagName, class: els[i].className },
          el2: { tag: els[j].tagName, class: els[j].className }
        });
      }
    }
  }
  return overlaps.slice(0, 10);
})()
```

## Spacing & Alignment

### Elements Too Close to Edge (< 8px margin from viewport)
```js
[...document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, span, a, button')]
  .filter(el => {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && (rect.left < 8 || (window.innerWidth - rect.right) < 8);
  })
  .slice(0, 10)
  .map(el => ({
    tag: el.tagName, class: el.className,
    left: Math.round(el.getBoundingClientRect().left),
    right: Math.round(window.innerWidth - el.getBoundingClientRect().right),
    text: el.textContent.trim().substring(0, 30)
  }))
```

## Images & Media

### Images Without Responsive Sizing
```js
[...document.querySelectorAll('img')].filter(el => {
  const s = getComputedStyle(el);
  return !s.maxWidth || s.maxWidth === 'none';
}).map(el => ({
  src: el.src.split('/').pop(),
  width: el.naturalWidth,
  displayWidth: Math.round(el.getBoundingClientRect().width),
  class: el.className
}))
```

### Oversized Images (display vs natural)
```js
[...document.querySelectorAll('img')].filter(el => {
  return el.naturalWidth > 0 && el.getBoundingClientRect().width > window.innerWidth;
}).map(el => ({
  src: el.src.split('/').pop(),
  naturalWidth: el.naturalWidth,
  displayWidth: Math.round(el.getBoundingClientRect().width),
  class: el.className
}))
```

## Common Device Viewports

| Device | Width | Height | DPR |
|--------|-------|--------|-----|
| iPhone SE | 375 | 667 | 2 |
| iPhone 14 | 390 | 844 | 3 |
| iPhone 14 Pro Max | 430 | 932 | 3 |
| Galaxy S21 | 360 | 800 | 3 |
| iPad Mini | 768 | 1024 | 2 |
| iPad Pro 12.9" | 1024 | 1366 | 2 |
