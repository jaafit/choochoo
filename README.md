# Nominator

A weighted random "nominator". Add players, mark who's present (they move to **The
Table**), then hit **Nominate** to pick a present player at random — weighted by how
many tickets each holds. Winning spends tickets; everyone who keeps showing up and
losing accrues more, so picks even out over time. Players persist in `localStorage`.

## Stack

Plain JavaScript with [Tailwind CSS](https://tailwindcss.com/) +
[DaisyUI](https://daisyui.com/), both loaded via CDN. **No build step, no framework.**

- `index.html` — page shell + CDN links
- `app.js` — all state and rendering
- `public/` — favicon, icons, manifest

## Running it

It's a static site — open `index.html` in a browser, or serve the folder:

```sh
npm start        # serves on http://localhost:3000
```

## Deploying

Copy `index.html`, `app.js`, and `public/` to any static host. There is nothing to
build. (Tailwind is loaded via the Play CDN, which is fine for this small personal
app; if you ever want a precompiled stylesheet, swap in a real Tailwind/DaisyUI build.)
