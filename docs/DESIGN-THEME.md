# Design Theme — Greenhouse IoT Dashboard

## Color Palette

Two anchor colors drive the entire system.
Derive ALL surfaces, text, borders, and accents from these two only.

Primary accent:   Cyprus   #0B3D36  (deep teal-green)
Base surface:     Sand     #F0EDE5  (warm off-white)

### Light Mode Tokens

```css
--color-bg:               #F0EDE5;
--color-surface:          #F5F3EE;
--color-surface-2:        #FAF9F6;
--color-surface-offset:   #E8E4DA;
--color-border:           rgba(11, 61, 54, 0.12);
--color-text:             #0B1F1C;
--color-text-muted:       #3D6B63;
--color-text-faint:       #8AADA8;
--color-primary:          #0B3D36;
--color-primary-hover:    #082E29;
--color-primary-active:   #051F1B;
--color-accent-warm:      #C4A882;
--shadow-sm: 0 1px 3px rgba(11, 31, 28, 0.06);
--shadow-md: 0 4px 14px rgba(11, 31, 28, 0.09);
--shadow-lg: 0 12px 32px rgba(11, 31, 28, 0.13);
```

### Dark Mode Tokens

```css
--color-bg:               #060F0D;
--color-surface:          #0B1A17;
--color-surface-2:        #0F2420;
--color-surface-offset:   #132B27;
--color-border:           rgba(30, 61, 56, 0.6);
--color-text:             #F0EDE5;
--color-text-muted:       #B8B0A3;
--color-text-faint:       #7A7469;
--color-primary:          #1A6B5E;
--color-primary-hover:    #228070;
--color-accent-warm:      #8C7355;
--shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.25);
--shadow-md: 0 4px 14px rgba(0, 0, 0, 0.35);
--shadow-lg: 0 12px 32px rgba(0, 0, 0, 0.45);
```

### Semantic Colors (alarm states only — never decorative)

```css
--color-critical:  #C0392B;
--color-warning:   #D4A017;
--color-ok:        #1A6B5E;
```

---

## Typography

Font pairing chosen for industrial IoT instrument-panel character.

```css
--font-display: 'DM Sans', sans-serif;
--font-body:    'IBM Plex Mono', monospace;
```

Load from Google Fonts:
- DM Sans — weights 300, 400, 500, 600
- IBM Plex Mono — weights 400, 500

### Application Rules

| Element | Font | Weight |
|---------|------|--------|
| Section headers, nav, card titles | DM Sans | 500-600 |
| KPI values, percentages | IBM Plex Mono | 500 |
| Timestamps, data readings | IBM Plex Mono | 400 |
| Button labels, status badges | DM Sans | 500 |
| Body paragraphs | DM Sans | 400 |

### Fluid Type Scale

```css
--text-xs:   clamp(0.75rem,  0.7rem  + 0.25vw, 0.875rem);
--text-sm:   clamp(0.875rem, 0.8rem  + 0.35vw, 1rem);
--text-base: clamp(1rem,     0.95rem + 0.25vw, 1.125rem);
--text-lg:   clamp(1.125rem, 1rem    + 0.75vw, 1.5rem);
--text-xl:   clamp(1.5rem,   1.2rem  + 1.25vw, 2.25rem);
```

---

## Spacing (4px base system)

```css
--space-1: 0.25rem;   --space-2: 0.5rem;    --space-3: 0.75rem;
--space-4: 1rem;      --space-6: 1.5rem;    --space-8: 2rem;
--space-10: 2.5rem;   --space-12: 3rem;     --space-16: 4rem;
```

---

## Border Radius

```css
--radius-sm:   6px;
--radius-md:   8px;
--radius-lg:   12px;
--radius-full: 9999px;
```

- Cards and panels: --radius-lg (12px)
- Buttons, inputs:  --radius-md (8px)
- Badges, chips:    --radius-full
- Small elements:   --radius-sm (6px)

---

## Chart Colors (Chart.js — no default palette)

```js
const CHART_COLORS = {
  temperature:    '#1A6B5E',
  humidity:       '#C4A882',
  co2_ok:         '#1A6B5E',
  co2_warning:    '#D4A017',
  co2_critical:   '#C0392B',
  reservoir_fill: '#0B3D36',
  reservoir_empty:'#E8E4DA',
  light_gradient_start: 'rgba(26, 107, 94, 0.25)',
  light_gradient_end:   'rgba(26, 107, 94, 0)',
  grid_lines:     'rgba(11, 61, 54, 0.10)',
};
```

Tooltip style:
- Background: --color-surface-2
- Text: --color-text
- Font: IBM Plex Mono, 12px

---

## Alarm States

### Fire Alarm (flamme == LOW)

- Full-page border: 2px solid --color-critical, pulsing keyframe animation
- Alert banner: slides down, --color-critical background, white text
- Web Audio API: 3 beeps at 880Hz, 200ms each
- All actuator toggles: disabled, opacity 0.5

### Warning (threshold exceeded)

- Alert banner: slides down, --color-warning background, --color-text dark
- Affected KPI card: border-color switches to --color-warning
- KPI status dot: --color-warning

### Normal (all clear)

- Alert banner: hidden (translateY -100%, display none after transition)
- KPI borders: revert to --color-border
- Status dots: --color-ok

---

## Responsive Breakpoints

| Viewport | Sidebar | KPI Grid | Charts |
|----------|---------|----------|--------|
| 1280px+ | Visible 220px | 6 columns | 2 columns |
| 768px | Icon rail 56px | 3 columns | 2 columns |
| 375px | Hidden (hamburger) | 2 columns | 1 column |

Mobile: bottom tab bar replaces sidebar nav on 375px.

---

## Base CSS Rules

```css
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

html {
  -webkit-font-smoothing: antialiased;
  scroll-behavior: smooth;
}

body {
  font-family: var(--font-display);
  font-size: var(--text-base);
  color: var(--color-text);
  background-color: var(--color-bg);
  min-height: 100dvh;
}

.data-value {
  font-family: var(--font-body);
  font-variant-numeric: tabular-nums;
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```
