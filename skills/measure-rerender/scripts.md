# evaluate_script 주입 스크립트

SKILL.md Phase 2~4에서 `evaluate_script`의 `function` 인자로 사용하는 스크립트 모음.

---

## inject-tracker

렌더 추적기를 페이지에 주입한다. Phase 2 Step 1에서 사용.

```javascript
() => {
  if (window.__RENDER_TRACKER__?.active) {
    return { status: 'already active', hasDevTools: !!window.__REACT_DEVTOOLS_GLOBAL_HOOK__ };
  }

  const tracker = {
    active: true,
    startTime: performance.now(),
    renders: [],
    componentCounts: {},
    domMutations: [],
    fiberCommits: 0
  };
  window.__RENDER_TRACKER__ = tracker;

  const hook = window.__REACT_DEVTOOLS_GLOBAL_HOOK__;
  if (hook) {
    function getComponentName(fiber) {
      if (!fiber) return null;
      if (fiber.type) {
        if (typeof fiber.type === 'string') return fiber.type;
        return fiber.type.displayName || fiber.type.name || 'Anonymous';
      }
      return null;
    }

    function walkFiber(fiber, rendered) {
      if (!fiber) return;
      const name = getComponentName(fiber);
      if (name && typeof fiber.type === 'function') {
        const flags = fiber.flags !== undefined ? fiber.flags : fiber.effectTag;
        const didRender = flags !== undefined ? (flags & 0b11) !== 0 : true;
        if (didRender) {
          rendered.push(name);
        }
      }
      if (fiber.child) walkFiber(fiber.child, rendered);
      if (fiber.sibling) walkFiber(fiber.sibling, rendered);
    }

    hook._originalOnCommitFiberRoot = hook.onCommitFiberRoot?.bind(hook);
    hook.onCommitFiberRoot = function(rendererID, root) {
      tracker.fiberCommits++;
      const rendered = [];
      try {
        const current = root.current;
        if (current) walkFiber(current, rendered);
      } catch (e) { /* fiber walking failed silently */ }

      const now = performance.now() - tracker.startTime;
      rendered.forEach(name => {
        tracker.componentCounts[name] = (tracker.componentCounts[name] || 0) + 1;
      });
      tracker.renders.push({
        time: Math.round(now * 100) / 100,
        commitIndex: tracker.fiberCommits,
        components: rendered.slice(0, 50)
      });

      if (hook._originalOnCommitFiberRoot) {
        return hook._originalOnCommitFiberRoot(rendererID, root);
      }
    };
  }

  const observer = new MutationObserver((mutations) => {
    const now = performance.now() - tracker.startTime;
    const summary = {};
    mutations.forEach(m => {
      const tag = m.target.tagName || 'TEXT';
      const id = m.target.id ? '#' + m.target.id : '';
      const cls = m.target.className && typeof m.target.className === 'string'
        ? '.' + m.target.className.split(' ')[0]
        : '';
      const key = tag + id + cls;
      summary[key] = (summary[key] || 0) + 1;
    });
    tracker.domMutations.push({
      time: Math.round(now * 100) / 100,
      count: mutations.length,
      targets: summary
    });
  });
  observer.observe(document.body, { childList: true, subtree: true, attributes: true });
  window.__RENDER_TRACKER__._observer = observer;

  return {
    status: 'tracking started',
    hasDevTools: !!hook,
    rendererCount: hook?.renderers?.size || 0
  };
}
```

---

## reset-tracker

추적 데이터를 초기화한다. 반복 측정 사이에 사용.

```javascript
() => {
  const tracker = window.__RENDER_TRACKER__;
  if (!tracker) return { status: 'no tracker found' };

  tracker.startTime = performance.now();
  tracker.renders = [];
  tracker.componentCounts = {};
  tracker.domMutations = [];
  tracker.fiberCommits = 0;

  return { status: 'reset complete' };
}
```

---

## collect-data

수집된 데이터를 반환한다. Phase 4 Step 1에서 사용.

```javascript
() => {
  const tracker = window.__RENDER_TRACKER__;
  if (!tracker) return { error: 'no tracker found' };

  const elapsed = Math.round((performance.now() - tracker.startTime) * 100) / 100;

  const sortedComponents = Object.entries(tracker.componentCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 30)
    .map(([name, count]) => ({ name, count }));

  const totalDomMutations = tracker.domMutations.reduce((sum, m) => sum + m.count, 0);

  const domHotspots = {};
  tracker.domMutations.forEach(m => {
    Object.entries(m.targets).forEach(([key, count]) => {
      domHotspots[key] = (domHotspots[key] || 0) + count;
    });
  });
  const sortedHotspots = Object.entries(domHotspots)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 15)
    .map(([target, count]) => ({ target, count }));

  return {
    elapsed,
    fiberCommits: tracker.fiberCommits,
    componentRenders: sortedComponents,
    renderTimeline: tracker.renders.slice(-20),
    totalDomMutations,
    domHotspots: sortedHotspots,
    hasDevTools: tracker.fiberCommits > 0
  };
}
```

---

## cleanup-tracker

추적기를 제거한다. 측정 완료 후 호출.

```javascript
() => {
  const tracker = window.__RENDER_TRACKER__;
  if (!tracker) return { status: 'no tracker found' };

  if (tracker._observer) {
    tracker._observer.disconnect();
  }

  const hook = window.__REACT_DEVTOOLS_GLOBAL_HOOK__;
  if (hook && hook._originalOnCommitFiberRoot) {
    hook.onCommitFiberRoot = hook._originalOnCommitFiberRoot;
  }

  delete window.__RENDER_TRACKER__;
  return { status: 'cleanup complete' };
}
```
