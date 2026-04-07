---
status: approved
created: 2026-04-06
---

# Global UI Design Contract

> Game-wide visual foundations for Coins & Boxes. Per-phase UI-SPECs reference this file and only define new components.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (LOVE2D immediate-mode UI) |
| Component library | none (hand-rolled love.graphics primitives) |
| Icon library | none (text labels + geometric shapes) |
| Font | comic shanns.otf (bundled custom font, single weight) |
| Canvas | 1080x1920 virtual, portrait, letterboxed |

---

## Spacing Scale

All values in virtual canvas pixels. All multiples of 4.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Cell gaps, inline padding between label and value |
| sm | 8px | Compact element spacing, panel internal padding |
| md | 16px | Corner radius for popup cards, default element margins |
| lg | 24px | Section padding within popup cards |
| xl | 32px | Gap between content sections |
| 2xl | 48px | Major spacing between title and content body |
| 3xl | 64px | Vertical margin above/below centered overlays |

**Touch targets:** minimum 80px height for all tappable buttons (matches `TAB_HEIGHT`).

---

## Typography

All fonts use "comic shanns.otf" loaded at different sizes.

| Role | Size | Weight | Line Height | Usage |
|------|------|--------|-------------|-------|
| Body | 36px | regular | 1.4 | Descriptions, body text, toast messages |
| Label | 25px | regular | 1.3 | Badges, small labels, progress fractions |
| Heading | 48px | regular | 1.2 | Popup titles, panel headlines |
| Display | 64px | regular | 1.1 | Hero numbers (level number, big stats) |

**Bold substitute:** comic shanns.otf is single-weight. Use size and color contrast for hierarchy, not faux-bold.

**Font refs in main.lua:**
- `font` (36px) = Body
- `font_small` (25px) = Label
- `font_heading` (48px) = Heading
- `font_display` (64px) = Display

---

## Color Palette

LOVE2D RGBA floats (0-1). Dark mossy-green palette.

| Role | Value (RGBA) | Hex Approx | Split |
|------|-------------|------------|-------|
| Dominant | (0.18, 0.22, 0.16, 1) | #2E3829 | 60% — background, card fills |
| Secondary | (0.08, 0.12, 0.08, 0.75) | #141F14 @ 75% | 30% — panels, toast bg, overlays |
| Accent | (0.25, 0.65, 0.35, 1) | #40A659 | 10% — CTAs, highlights |
| Destructive | (0.80, 0.38, 0.22, 1) | #CC6138 | Warnings, danger states |

### Accent Reserved For
- Primary action buttons (Collect, Claim, Continue)
- Completion indicators (checkmarks, filled progress)
- Accent stripes on notification banners

### Semantic Colors (established)
| Semantic | Value | Usage |
|----------|-------|-------|
| Fuel | (1, 0.75, 0.15) | Fuel icons/amounts |
| Stars | (0.95, 0.85, 0.25) | Star icons/amounts, gold emphasis |
| Bags | (0.8, 0.6, 0.3) | Bag icons/amounts |
| Text primary | (0.92, 0.88, 0.78) | All primary text on dark bg |
| Text secondary | (0.65, 0.68, 0.58) | Subtitles, inactive labels |
| Dimmer backdrop | (0, 0, 0, 0.7) | Semi-transparent overlay behind modals |
| Panel border | (0.3, 0.5, 0.3, 0.4) | Panel outlines |

---

## Drawing Order (Z-Order)

Strict layer order in every screen's `draw()`:

```
1. Background + game content (grid, coins, boxes)
2. Particles (particles.draw())
3. Effects (effects.draw() — fly-to-bar, burst, flash)
4. HUD (resource bars, panels)
5. Toast banners (popups.drawToasts())
6. Modal popups with dimmer (popups.drawModal())
7. Tab bar (tab_bar.draw())
```

Tab bar always on top — navigation must remain accessible during overlays.

---

## Common Interaction Patterns

### Input Priority Chain
```lua
-- In every screen's mousepressed():
-- 1. Modal popup (blocks all input, requires button tap)
-- 2. Toast banner (non-blocking, tap dismisses)
-- 3. Normal game input
```

### Button Press Feedback
- Scale to 0.95 on press (existing pattern across all buttons)
- All tappable areas >= 80px tall

---

## Platform Considerations

| Platform | Adjustment |
|----------|-----------|
| Web/WASM | `mobile.isLowPerformance()` halves particle counts. All animations are Lua tween-based. |
| Mobile touch | All buttons >= 80px tall. Touch debounce in main.lua handles SDL double-fire. |
| Desktop | No differences — same virtual canvas pipeline. |

---

## Registry Safety

No external Lua dependencies. LOVE 12.0 built-in APIs only. No registry vetting required.

---

*Global contract for Coins & Boxes*
*Created: 2026-04-06*
