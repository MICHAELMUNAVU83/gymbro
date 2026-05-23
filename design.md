# GymBro — UI Redesign Spec

A clean, minimalistic, light-themed redesign with a single red accent. Built to scale from mobile (375px) to wide desktop (1440px+) using the same component vocabulary.

---

## 1. Design principles

1. **Light & quiet.** Off-white background, soft neutrals, generous whitespace. The eye should rest on content, not chrome.
2. **One accent, used sparingly.** Red is reserved for the *primary action* on a screen (Start workout, Log set, Complete workout) and for live/critical status. Never decorative.
3. **Type does the heavy lifting.** Strong type hierarchy replaces boxes-inside-boxes. Most "cards" are just whitespace + a hairline divider.
4. **Two-column on desktop, single column on mobile.** Same components, different container width. No separate desktop layout.
5. **No glow, no gradients, no neon.** Static, print-quality flatness. Subtle shadow only where elevation is meaningful (modals, sticky bars).

---

## 2. Color system

Replace the existing dark `:root` tokens in [assets/css/app.css](assets/css/app.css) with the palette below. All values WCAG AA on the light surface.

```css
:root {
  color-scheme: light;

  /* Surfaces */
  --bg:           #FAFAF7;   /* page background — warm off-white */
  --surface:      #FFFFFF;   /* cards, sheets */
  --surface-alt:  #F4F4F0;   /* subtle fills, input bg, hover */
  --border:       #E7E5E0;   /* hairlines */
  --border-strong:#D6D3CC;   /* focused inputs, dividers under headers */

  /* Text */
  --text:         #18181B;   /* primary */
  --text-muted:   #5C5C66;   /* secondary */
  --text-subtle:  #9A9AA3;   /* labels, captions */

  /* Accent (red) — the only chromatic color used at meaningful scale */
  --accent:       #E11D2A;   /* primary red */
  --accent-hover: #C8121E;
  --accent-soft:  #FDECEE;   /* red on white tinted background */
  --accent-ring:  rgba(225, 29, 42, 0.22);

  /* Semantic (used at low saturation, no glow) */
  --success:      #1F8A4C;
  --success-soft: #E6F4EC;
  --warning:      #A86A00;
  --warning-soft: #FBF1DC;
  --danger:       var(--accent);

  /* Live / in-session indicator only — small dot, never a fill */
  --live:         #1F8A4C;
}
```

Remove the radial-gradient backdrop from `html`. Use a flat `--bg`.

---

## 3. Typography

Keep the system stack. Define a clear scale:

| Token        | Size / Line | Weight | Use                                       |
|--------------|-------------|--------|-------------------------------------------|
| `display`    | 40 / 44     | 700    | Hero on landing only                      |
| `h1`         | 28 / 34     | 700    | Screen title (Upper Builder)              |
| `h2`         | 20 / 26     | 600    | Section header                            |
| `h3`         | 16 / 22     | 600    | Card title (exercise name)                |
| `body`       | 15 / 22     | 400    | Prose                                     |
| `body-sm`    | 14 / 20     | 400    | Secondary lines                           |
| `label`      | 11 / 14     | 600    | UPPERCASE, +0.08em tracking, `--text-subtle` |
| `mono-stat`  | 22 / 26     | 600    | Numeric stats                             |

- Drop letterspacing on body text.
- Labels (DURATION, EXERCISES, STATUS, WEEK 1 · DAY 1) stay uppercase but become smaller and quieter — they're metadata, not headlines.

---

## 4. Spacing, radius, shadow

- **Spacing scale** (px): 4, 8, 12, 16, 20, 24, 32, 40, 56, 72.
- **Radius**: `--radius-sm: 8px`, `--radius: 12px`, `--radius-lg: 16px`, `--radius-pill: 999px`. No more 24px+ blob radii.
- **Shadow** (use sparingly):
  - `--shadow-sm: 0 1px 2px rgba(20, 20, 23, 0.04);`
  - `--shadow-md: 0 4px 12px rgba(20, 20, 23, 0.06);`
  - Cards do **not** get shadow by default — they get a 1px `--border`. Shadow only on sticky bars, modals, and the floating tab bar on mobile.

---

## 5. Layout

### App shell

Current shell is locked to `max-width: 390px`. Change to a responsive shell:

```css
.app-shell {
  width: 100%;
  max-width: 1120px;       /* desktop */
  margin-inline: auto;
  padding-inline: clamp(16px, 4vw, 40px);
}
```

### Page grid

- **Mobile (<768px):** single column, full width.
- **Tablet/Desktop (≥768px):** 12-column grid, `gap: 24px`. Most screens use:
  - Left: primary content (8 cols)
  - Right: meta panel / stats / session control (4 cols, sticky)

### Navigation

- **Mobile:** keep the bottom tab bar. Restyle: white surface, 1px top border, no glow. Active tab = red icon + red label, no pill background.
- **Desktop (≥1024px):** replace tab bar with a **left rail** (72px wide, icon-only with tooltip, or 220px expanded). Same four destinations: Home, Workouts, Body stats, Settings. The rail is the only persistent chrome; content fills the rest.

---

## 6. Components

### 6.1 Card

```
┌─ surface=white, border=1px var(--border), radius=12, padding=20/24 ─┐
│  LABEL (label token)                                                │
│  Big number or title                                                │
│  Optional secondary line (text-muted)                               │
└──────────────────────────────────────────────────────────────────────┘
```

Cards never nest. If you feel the urge to nest a card inside a card, use a `<hr>` (`border-top: 1px solid var(--border)`) and indentation instead.

### 6.2 Stat tile

Replace the three rounded "DURATION / EXERCISES / STATUS" tiles with a single horizontal row separated by hairlines:

```
DURATION         EXERCISES        STATUS
58 min           4                Ready
─────────────────────────────────────────
```

On mobile, stack vertically with a 1px divider between each.

### 6.3 Buttons

| Variant     | Bg               | Text             | Border           | Use                              |
|-------------|------------------|------------------|------------------|----------------------------------|
| Primary     | `--accent`       | white            | none             | One per screen. Start workout, Log set, Complete workout. |
| Secondary   | `--surface`      | `--text`         | 1px `--border`   | Back, Cancel, secondary nav      |
| Ghost       | transparent      | `--text-muted`   | none             | Inline actions, dismiss          |
| Destructive | `--surface`      | `--accent`       | 1px `--accent`   | Delete, end session              |

- Radius: `--radius-pill` for primary CTAs (keeps the energetic feel), `--radius` for everything else.
- Sizes: `sm` 32px / `md` 40px / `lg` 48px. Touch target ≥ 44px on mobile — use `lg` for primary CTAs on mobile.
- Focus ring: `0 0 0 3px var(--accent-ring)`.

### 6.4 Status pill

Currently `READY` shows as a red-tinted block on every day card, which over-uses red. Redo:

- `Ready` → text-only, `--text-muted`, no pill.
- `Live / In session` → small green dot + `Live` label.
- `Completed` → checkmark icon + muted text.
- `Skipped` → strikethrough title, muted.

Reserve filled pills for things you actually want users to *act on*.

### 6.5 Inputs (REPS, WEIGHT KG, etc.)

- Background: `--surface-alt`.
- Border: 1px `--border`, focus → 1px `--border-strong` + 3px `--accent-ring`.
- Label sits *above* the field in `label` token style.
- Numeric inputs use the `mono-stat` token at rest so the value reads as data, not as text.

### 6.6 Trainer notes / callout

Drop the warm brown panel. Use:

```
┌─ left border 3px var(--accent), bg=var(--accent-soft), padding=16 ─┐
│  TRAINER NOTES                                                     │
│  Stay one rep shy of failure on the final set.                     │
└────────────────────────────────────────────────────────────────────┘
```

Or, for non-critical info, drop the accent entirely and use `--surface-alt` with no border.

### 6.7 Toast / error banner

Current "Something went wrong" floats over content and obscures the page title. Redesign:

- Slide in from top, anchored under the top bar (not overlapping it).
- Width: matches content column, max 480px.
- Background: `--surface`, 1px `--danger` border, `--shadow-md`.
- Icon + message + close in a single row. No body sub-text unless there's an action.
- Auto-dismiss after 5s for non-blocking errors.

### 6.8 Bottom tab bar (mobile only)

- Background: `--surface` (white), `--shadow-md` upward, 1px top `--border`.
- 4 items, equal width, 56px tall + safe area.
- Inactive: icon `--text-muted`, label `--text-subtle`.
- Active: icon `--accent`, label `--text` (no fill background, no glow). 2px red underline indicator above the icon, 24px wide.

---

## 7. Screen-by-screen application

### 7.1 Workout detail (screenshot 1 — "Upper Builder")

**Mobile**

```
←  Back                                  WEEK 1 · DAY 1
─────────────────────────────────────────────────────────
Upper Builder
Chest · Back · Shoulders

DURATION    EXERCISES    STATUS
58 min      4            Ready
─────────────────────────────────────────────────────────

[ Start workout — primary, full-width, 48px ]
Spin up the logger and track each set in real time.

╎ TRAINER NOTES
╎ Stay one rep shy of failure on the final set.

Exercise plan
─────────────────────────────────────────────────────────
1.  Incline Dumbbell Press      4 × 8–10  ·  26 kg   75s rest
─────────────────────────────────────────────────────────
2.  Chest-Supported Row         4 × 10–12 ·  ...     60s rest
...
```

**Desktop (≥1024px)**

Two-column. Left (8 cols): title block + exercise list. Right (4 cols, sticky at top:24px): stat row + Start workout CTA + trainer notes.

### 7.2 Week overview (screenshot 2)

- Hero title: just the headline, no card wrapper, plenty of margin above.
- Each day card: 1px border, no shadow, hover (desktop) lifts the border to `--border-strong`. Exercise chips become inline muted text instead of pills: `Incline DB Press · Chest-Supported Row · Cable Lateral Raise`.
- Desktop: 2-up grid for day cards. Mobile: stacked.

### 7.3 Live session (screenshot 3 — "Conditioning Finish")

This is the one screen where the accent earns its keep.

- Top status strip is white with a small green dot + `LIVE` label and the elapsed timer in `mono-stat`.
- "0 sets logged" + Complete workout: on mobile this becomes a sticky bottom bar (white, shadow up). On desktop it lives in the right rail and stays visible without sticking.
- Exercise card layout: title + meta on left, "NEXT SET 1" stat on right. Active set's input form expands inline; others collapse to a one-line summary.
- `Log set` is the only red button on screen until a set is logged.

### 7.4 Body stats (screenshot 4)

- Hero text block left, stat row right on desktop (single column on mobile).
- Chart: keep the line, but recolor to `--accent` instead of blue (this is the *one* place outside CTAs where chromatic ink is justified — it's the data). Gridlines `--border`, axis labels `--text-subtle`. No fill, no glow.
- Stat tiles → same row treatment as §6.2.

---

## 8. Motion

- Page enter: 200ms ease-out fade + 4px upward translate (current is 320ms / 12px — too theatrical for a light UI).
- Button press: 80ms scale to 0.98.
- Toast: 180ms slide-down.
- Respect `prefers-reduced-motion`.

---

## 9. Iconography

- Stick with Heroicons (already in [tailwind.config.js](assets/tailwind.config.js)).
- Use `outline` at 20px throughout. Switch to `solid` only when an icon is *selected* (e.g. active tab) or carries semantic weight (filled red exclamation for danger).
- Color: `--text-muted` by default, `--accent` only when active.

---

## 10. Implementation order

1. Swap the CSS variables in [assets/css/app.css](assets/css/app.css), drop the dark `color-scheme` and the gradient background. Verify the app still renders.
2. Widen `.app-shell` and introduce the responsive grid utility.
3. Rebuild the four primitive components in [lib/gym_bro_web/components/core_components.ex](lib/gym_bro_web/components/core_components.ex): `card`, `button`, `stat_row`, `callout`.
4. Migrate one screen end-to-end (suggest: workout detail — it's the densest) and confirm the system holds.
5. Roll the system across the remaining screens. Delete unused dark-mode tokens and gradients as you go.
6. Add the desktop left rail behind a `≥1024px` media query — do this last, after the mobile layout is solid.

---

## 11. Don'ts

- No glassmorphism, no backdrop blur, no neon glow.
- No nested cards.
- No more than one red button per screen.
- No status pills for passive states (`Ready`, `Scheduled`). Use plain text.
- No icon-only buttons without an `aria-label`.
- No fixed pixel widths on text containers — use `max-width` in `ch` units for readable paragraphs (60ch).
