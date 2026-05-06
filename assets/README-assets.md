# Asset placeholders

This directory holds shared assets for the landing pages.

## Currently shipped

- `favicon.svg` — minimal "pin in a frame" SVG favicon (Atika brand color)
- `styles.css` — all landing-page styles

## Required before going live

Production assets you must create / commission:

| File | Spec | Used by |
|---|---|---|
| `og-greece.png` | 1200 × 630 | Greece landing pages (EN + EL), social shares |
| `og-israel.png` | 1200 × 630 | Israel landing pages (EN + HE), social shares |
| `og-default.png` | 1200 × 630 | Franchise root + privacy/terms |
| `apple-touch-icon.png` | 180 × 180 | iOS home-screen icon when added to home |
| `logo.png` | 512 × 512 | JSON-LD `logo` field, press kit |

## Suggested OG image content

**Greece OG image:**
- Background: deep Mediterranean blue (`#1B3A5C`)
- Foreground: subtle white-line topo map of Greece with pin clusters
- Title: "17,880 ancient sites in Greece"
- Subtitle: "Atika — Walk, drive, discover."
- Type: EB Garamond serif (or any classic serif)

**Israel OG image:**
- Background: warm sandstone (`#B8814C`)
- Foreground: subtle topo map of Israel with pin clusters
- Title: "12,000 archaeological sites in Israel"
- Subtitle: "Atika — Walk, drive, discover."

**Default OG image:**
- Background: Earth tone gradient (sandstone → terracotta)
- Title: "Atika"
- Subtitle: "Walk, drive, discover."
- Three small map silhouettes (Greece, Italy, Israel) below

## Tools to create these

- Figma (free) — most flexible
- Canva (free) — fastest
- ImageMagick / Pillow (script) — if you want them generated programmatically per-country

## Don't bother with

- Stock travel photography of tourists
- Generic "ancient ruins" stock images (looks like every other travel app)
- Heavy gradients or 3D effects
- Animated PNGs / GIFs (broken on most platforms)

Keep it Taschen-book-cover clean.
