# Per-day maps

Inline SVG, drawn from OSRM geometry. No tiles, no JavaScript, no network.

## Why not a tile map

A page under a strict Content-Security-Policy cannot load tiles from
`tile.openstreetmap.org` or Leaflet from a CDN. Inline SVG sidesteps all of it,
works offline, inherits the page's light/dark theme, and costs a few KB per
map. You lose the basemap: no coastline, no towns you didn't mark. For a route
map that is a fair trade — the line and its stops are the content.

### "Can't we just embed a Google map?"

Not an interactive one. A published artifact runs under a strict
Content-Security-Policy that blocks every external host — CDN scripts, remote
images, fetch, XHR, WebSockets. Google Maps needs `maps.googleapis.com`, so it
never loads. Same reason Leaflet and OSM tiles don't.

Three things do work, in ascending order of cost:

- **A link.** `https://www.google.com/maps/dir/?api=1&…` opens the native app
  with the whole multi-stop route and real turn-by-turn. This is the one that
  matters, and it costs nothing.
- **Inline SVG**, drawn from the route geometry. No network at run time, themes
  correctly, and **4.1 KB per map** measured over fourteen day-maps (57 KB for
  all of them, in a 186 KB page).
- **A static map baked in as a `data:` URI.** The CSP blocks requests, not
  content already in the page, so fetching a Static Maps PNG at generation time
  and embedding it base64 does work. It costs an API key with a billing quota,
  network at generation time, and roughly 100 KB per map — 15–30× the SVG.
  Fourteen of those push a page past a megabyte, which is the failure this
  project already hit once at 743 KB.

Take the basemap only if the trip genuinely needs coastlines and town names.
For a route and its stops, the line is the content.

## Projection

Equirectangular, scaled by the cosine of the mean latitude:

```python
lat0 = sum(lats) / len(lats)
k    = math.cos(math.radians(lat0))    # longitude degrees are shorter here
x    =  lon * k * esc + ox
y    =  oy - lat * esc                 # y grows downward; north must be up
```

At a 200 km box this is exact for any practical purpose. Mercator adds nothing
and complicates the scale bar.

To label a scale bar, one unit of `esc` is:

```python
km_per_unit = math.radians(1) * 6371.0 / esc
```

Pick a round bar length with a 1-2-5-10 sequence starting from
`10 ** floor(log10(km_per_unit * 120))`.

## Simplification

Raw geometry is far denser than any drawing needs — 6,000 points for one day,
11,111 for a 594 km route. Embedded raw, twelve days weighed **743 KB**; a page
nobody can open on mobile data. Simplified: **190 KB**.

Use Ramer–Douglas–Peucker, **iteratively, with an explicit stack**. The
recursive formulation overflows Python's stack at this size — this is not a
theoretical risk, it happened.

Simplify in **canvas space, not in degrees**, with a tolerance of ~0.4 px: at
final scale, two points closer than half a pixel draw the same thing, and a
pixel tolerance is meaningful at any zoom or latitude. Emit path coordinates
with one decimal; more is noise that only inflates the file.

Perpendicular distance from point to segment:

```python
norm = math.hypot(dx, dy) or 1e-9
d = abs(dy * x - dx * y + x2 * y1 - y2 * x1) / norm
```

## Readability

- Alternate stop labels above and below the line (`dy = -11` / `+17`) so
  consecutive marks don't overlap.
- Mark the endpoints differently from intermediate stops.
- A small "N ↑" arrow orients the reader faster than any caption.
- Wrap a wide map in a horizontally scrollable container rather than shrinking
  it until the labels are unreadable.
- Give the `<svg>` `role="img"` and an `aria-label` that states the route.

## Navigation links

**OpenStreetMap**, to view the area. There is no public URL that draws a route,
only a viewport, so compute the zoom that fits the bounding box. At zoom `z`
the world is `256 * 2**z` px wide over 360°, so for a ~900 px viewport:

```python
dlon = max(max(lons) - min(lons), (max(lats) - min(lats)) * 1.6, 0.02)
z    = max(7, min(13, int(math.log2(1266 / dlon))))
url  = f"https://www.openstreetmap.org/#map={z}/{clat:.4f}/{clon:.4f}"
```

The `1.6` compensates for a viewport wider than it is tall; the `0.02` floor
stops a single-stop day from zooming to the street.

**Google Maps**, to actually navigate:

```
https://www.google.com/maps/dir/?api=1
  &origin={lat},{lon}
  &destination={lat},{lon}
  &waypoints={lat},{lon}%7C{lat},{lon}%7C…
  &travelmode=driving
```

Note the axis order flips: `lat,lon` here, `lon,lat` in OSRM. Waypoints are
joined by a URL-encoded pipe (`%7C`), five decimals is plenty, and the API
accepts at most **9 intermediate waypoints**.

This is the only option that navigates a whole multi-stop route. GPX is not
importable by the phone apps, and **Waze cannot import a route at all** — it
accepts one destination and picks its own way there. If someone insists on
Waze, give them one link per stop.
