---
name: road-trip
description: Plan and maintain a multi-day driving trip — daily legs with real routing, departure times that work backwards from a fixed appointment, sunset-aware arrivals, offline per-day maps, and fuel/campsite budgets calibrated against what trips actually cost. Use when building a road-trip itinerary, computing driving times and departure hours, estimating fuel or camping spend, generating route maps, or keeping a live plan in sync with a trip in progress.
---

# Road trip planning

A trip plan is a **program**, not a document. Hours, distances and costs are
derived from a small set of hand-edited facts; everything else is generated.
The moment you hand-edit a derived number, the plan starts lying — and it lies
silently, because nothing recomputes.

This skill is distilled from a real 12-day, 2,050 km trip across northern
Spain. The numbers in it are measured, not guessed.

## The pipeline

Keep one source of truth per kind of fact, and generate the rest:

```
stops.py      days and their stops (label, geocoding query)   ← hand-edited
      │
      ├─ geocode ─→ geocache.json ──┐
      │                             ├─→ legs.json (distance + duration per leg)
      └─ OSRM /route ───────────────┘
                                     │
      ┌──────────────────────────────┴──────────────┐
      ↓                ↓                ↓           ↓
  gen_html.py      relojes.py       mapas.py    schedule.py
  (legs, table)    (day clock)      (SVG maps)  (departure times)
```

Run order matters: routing first (it writes the cache), then the HTML
generators, and maps last if they anchor to blocks the other generators emit.

**Rules that cost real work to learn:**

- **Never edit generated output.** Fix the generator. A note edited directly
  into the HTML silently disappeared on the next run — twice, before the cause
  was obvious.
- **Validate every anchor before writing anything.** An `assert` that fires
  halfway through leaves the file half-patched. Count all the insertion points
  first, then apply.
- **Insert from back to front** so earlier offsets stay valid.
- **Make regeneration idempotent**: delete the previous generated block before
  inserting the new one, or you accumulate two versions of everything.
- **Key positional data by an explicit code**, not by array position. Days keyed
  by a two-digit prefix (`"01 Fisterra"`) survive reordering; indexes do not.

## Where this runs

The knowledge in this skill is environment-independent. The recipes are not —
half of them assume a shell and Docker. **Check what you actually have before
promising a routed plan.**

| | Claude Code | Claude apps (claude.ai) |
|---|---|---|
| Shell, Docker, self-hosted router | yes | no |
| Arbitrary network calls | yes | assume none |
| Read files the user provides | yes | yes |
| Write files for the user | yes | yes |

One copy of the skill serves both: a skill enabled on claude.ai syncs down into
Claude Code by itself. So write the tool-dependent half to **degrade, not
fail** — say which tier you are on, and never present an estimate as if it were
routed.

**The portable artifact is `legs.json`**: one entry per leg with `km` and
`seconds`. Everything downstream — the day clock, departure times, budgets,
even the maps if you also save the geometry — is arithmetic over that file and
needs no network. Route once where you have the tools, carry the JSON
anywhere. When a user arrives in a chat with no shell, ask for that file before
assuming you have to estimate.

## Routing

Three tiers. Say out loud which one you used.

**1. Self-hosted OSRM.** Worth it above a few dozen requests, or when you want
no rate limits and no network. See `reference/osrm.md`; `scripts/osrm-up.sh`
builds and serves it. Four Spanish regions: 354 MB of extracts → 1.7 GB graph,
~15 min to build, **140 MB RAM** at rest. Cheap enough to leave running.

**2. A public routing API.** Fine for one trip's worth of requests. Same
endpoints and the same lon,lat trap; mind the rate limit and the terms.

**3. No router at all.** Estimate from great-circle distance. Measured over 65
real legs, road distance is **1.55 × straight line** (median) — but the spread
is wide: p10 1.22, p90 2.36, and a coastal cape hit 6.46. Duration: **52 km/h**
median per leg, 56 km/h over a whole trip.

That is good enough to tell a two-hour day from a five-hour day, and to catch a
stage that obviously does not fit. **It is not good enough to schedule an
anchored appointment**, and you should say so rather than let a ±30% number
masquerade as a plan. Coastal and mountain roads are the worst case; motorway
legs land near 1.2.

Two endpoints do all the work:

- `/route/v1/driving/{lon,lat};{lon,lat};…?overview=false&annotations=false`
  — one request per day. OSRM returns one leg per consecutive pair, so a
  seven-stop day costs one call, not six.
- `/route/v1/driving/{…}?overview=full&geometries=geojson` — the drawable
  geometry, when you need a map.

**Routing precision is not your problem.** Two independent routers agreed to
within 0.3% over 1,800 km. Geocoding was off by 2–4.5 km. Spend your effort
there.

Without a shell, geocoding has the same tiering: ask the user for coordinates,
or accept named places and flag that you could not verify them. A plan built on
unverified place names is exactly the plan that sends someone 34 km wrong.

## Geocoding

This is where trips break. A municipality's *boundary* centroid can sit in the
hills 4 km from where anyone would say the town is. Full detail, query
parameters and the validation checks are in `reference/geocoding.md`.

Tiered like the routing, and again: say which tier you used.

**1. LocationIQ, with a token the user provides.** Free tier, and measurably
the best of the cheap options — it returned the urban centre for 7 of 8 large
municipalities where Nominatim missed by 2–4.5 km. **Offer it, don't assume
it**: ask only when the trip has enough city stops that kilometres of error
per stop would move the departure times, explain that it is free, and accept
"no" without argument.

Treat the token as a secret. Environment variable or a gitignored file, never
a literal in code, **never written into generated output or echoed back**, and
not persisted anywhere the user did not ask for. It is their key, pasted into a
chat on trust.

**2. Nominatim.** No token, 1 req/s, needs an identifying User-Agent. Good on
monuments and addresses, weak on cities — it is the one returning polygon
centroids.

**3. Neither.** Ask for coordinates, or accept the names and state plainly that
they are unverified. An unverified name is exactly what sends someone 34 km
wrong.

Whichever tier you are on, these still apply:

- **If the top hit is a `boundary`, require a `place` node inside its bounding
  box.** Without that containment check a same-named town in another province
  slips in — one stray "Vigo" stretched a leg from 240 to 319 km.
- **Aim at a monument, not a city.** `"Catedral de León, León, España"` beats
  `"León"`, which lands in the geometric centre of the province, 34 km out.
  Fixing this in the data beats any amount of code.
- **Snap-check every point** against the router's `/nearest`. A town centre
  snaps within ~50 m of a named street; a polygon centroid 300–600 m from a
  forest track. Capes and beaches snap far away legitimately — warn, never
  abort.
- **Cache by the full query string** and write the cache after every hit, not
  at the end of the run.

## Maps

Per-day inline SVG, drawn from the route geometry. See `reference/maps.md` for
the projection, the simplification and the URL formats.

Why inline SVG rather than a tile map: a strict Content-Security-Policy blocks
CDN tiles and Leaflet. Inline SVG needs no network, adapts to light and dark,
and weighs a few KB.

Two numbers that matter:

- **Simplify the polyline, in canvas space, at ~0.4 px tolerance.** One day's
  raw geometry was 6,000 points and the page weighed 743 KB — unusable on
  mobile data. After simplification, 190 KB for twelve maps.
- **Ramer–Douglas–Peucker must be iterative.** The recursive form blows the
  Python stack at 6,000 points.

For turn-by-turn navigation, emit a Google Maps directions URL with waypoints
joined by `%7C`. It is the only thing that will navigate a whole multi-stop
route: GPX doesn't import, and **Waze cannot import routes at all** — it only
accepts a single destination. The API caps intermediate waypoints at 9.

## Timing

Model each day as either **anchored** or **free**:

- *Anchored*: a fixed appointment (a guided tour at 12:15). Resolve the
  departure time **backwards**, summing only the legs and stops that come
  before it. Never estimate the offset by eye.
- *Free*: a chosen departure time; resolve forwards.

Then check the arrival against sunset. Compute sunset with the NOAA algorithm
(`reference/timing.md`) — it needs only date, latitude and longitude, and it is
accurate to the minute. **Flag any day arriving with less than 30 minutes of
light left**, because arrival means "tent up", not "wheels stopped".

Sunset moves. Going east across northern Spain in August cost 36 minutes of
evening light in twelve days.

Router times are **free-flow**. No router models traffic: add 10–15% in August
or at rush hour.

## Budget

Two systematic biases, both measured:

**Campsites bill per unit, not per pitch.** The price you see in search results
is usually the pitch alone. Real cost = 2 adults + tent + car + electricity.
Estimating 25 €/night came in **24% low**; the real average was 31.35 €/night
(range 19.95–44.00, August, VAT included). Electricity ~6 €/night rarely pays
for itself in a tent.

**Fuel: account tank to tank, and inflate the distance.** Planned 1,798 km at
6.5 l/100 km and 1.70 €/l → 202 €. Actual: 244.50 €, **+21%**. The split is
instructive — a third was the fuel price being 1.78–1.86 €/l, and the rest was
~250 km nobody plans: driving back to the campsite, hunting for parking,
wrong turns. **Real km ≈ planned km × 1.14.**

Budget the whole trip, then state what it excludes. The example trip: campsites
345 € + fuel 244.50 + tolls 15 + activities 183 ≈ **787 € for two, food
excluded** (add 25–35 €/day cooking at the campsite).

## Calibration numbers

Useful defaults when you have nothing better:

| Quantity | Value |
|---|---|
| Average speed, mixed roads | 56 km/h |
| Average speed, coastal road | 48 km/h |
| Average speed, motorway | 61 km/h |
| Comfortable daily stage | 150 km / 2 h 40 driving |
| "Long day" (worth flagging) | 5 h 54 driving |
| Pitching a tent | 45 min day 1, 35 day 2, 25 thereafter |
| Lunch stop | 90 min (75–120) |
| Viewpoint / cape | 30–45 min |
| Large beach | 60–180 min |
| Museum or cave | 90–150 min |
| Town you pass through | 0 min — name what to see, or don't stop |
| Light margin before sunset | ≥ 30 min |
| Traffic surcharge (August) | +10–15% |
| Real vs planned distance | ×1.14 |

## Keeping the plan alive

A plan is most useful *during* the trip, which means reconciling it with
reality every day: the price actually paid, the campsite actually used, the
hour you actually left. Record the real value, then **recompute** — do not
patch the rounded total, or the arithmetic drifts. Summing a corrected table
once caught a total that was one euro off and had been "fixed" by hand.

When a booking falls through, the honest move is to remove the stop and
re-route, not to leave it in the plan with a note. The times downstream are
wrong until you do.
