# SPEC.md Format Reference

## File Structure

```markdown
# [App Name] — Specification

## Overview

## Screens
### [Screen Name]
...one section per screen...

## Core Logic
### [Algorithm/Feature Name]
...

## Data Model
### [Entity Name]
...
```

---

## Section Guidelines

### Overview

One paragraph. Cover: what the app does, who it's for, and the primary user flow.

```markdown
## Overview

Single-page React app that analyzes color preferences to determine a user's
personal color type. Users swipe through color cards, and the app recommends
a seasonal color palette (one of 12 types) based on their selections.
```

---

### Screens

One subsection per distinct screen or route. Use the subsections below.

```markdown
### [Screen Name]

**Purpose**
What this screen is for and when the user reaches it.

**UI Elements**
- [Element name]: [What it shows or does]
- [Element name]: [What it shows or does]

**User Actions**
| Action | Trigger | Result |
|--------|---------|--------|
| [Action] | [Button / key / gesture] | [What happens next] |

**State**
- Manages: [list of state variables this screen owns]
- Transitions to: [next screen] when [condition]

**Behavior**
- [Edge case or special rule]
- [Edge case or special rule]
```

Rules:
- **UI Elements**: list only meaningful elements, not every div
- **User Actions**: cover all inputs — buttons, keyboard shortcuts, gestures
- **State**: list what state this screen owns, not derived/prop values
- **Behavior**: cover edge cases, empty states, loading states, error states

---

### Core Logic

One subsection per non-trivial algorithm or data transformation. Omit trivial CRUD.

```markdown
### [Function / Algorithm Name]

- **Input**: [what it receives]
- **Process**: [what it does, step by step if needed]
- **Output**: [what it returns]
- **Edge cases**: [what happens with invalid/empty input]
```

Example:
```markdown
### Personal Color Analysis

- **Input**: Array of liked color objects (`{ hex, hsl: { h, s, l } }`)
- **Process**:
  1. Calculate circular mean of hue values
  2. Determine warm/cool from avg hue (0–60° or 300–360° = warm)
  3. Determine season: warm+light → Spring, warm+dark → Autumn, cool+light → Summer, cool+dark → Winter
  4. Determine tone: lightness > 75 → Light, saturation > 65 → Bright, else Muted
- **Output**: Season-tone string (e.g. `"Spring Light"`)
- **Edge cases**: Empty array → returns `null`
```

---

### Data Model

One subsection per key data structure. Use inline TypeScript or JSON notation.

```markdown
### [Entity Name]

Description of what this represents.

```ts
{
  name: string       // display name
  hex: string        // e.g. "#FFCBA4"
  hsl: {
    h: number        // 0–360
    s: number        // 0–100
    l: number        // 0–100
  }
}
```
```

Rules:
- Include only structures that are non-obvious or shared across the app
- Add inline comments for fields that need explanation
- Note how data is organized at the top level (e.g. "keyed by season-tone string")

---

## Formatting Conventions

- Section headers: `##` for top-level, `###` for sub-items
- Tables for user actions (more scannable than bullet lists)
- Code blocks for data structures
- Keep each Screen section self-contained — don't assume the reader has read others
