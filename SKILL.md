---
name: road-trip
description: Plan and maintain a multi-day driving trip — daily legs with real routing, departure times that work backwards from a fixed appointment, sunset-aware arrivals, offline per-day maps, and fuel/lodging budgets calibrated against what trips actually cost. The method works in any country, season, unit system or currency; every trip-specific constant is tagged and replaceable. Use when building a road-trip itinerary, computing driving times and departure hours, estimating fuel or camping spend, generating route maps, deriving calibration for a new region or season, or keeping a live plan in sync with a trip in progress.
---

# Road trip planning

A trip plan is a **program**, not a document. Hours, distances and costs are
derived from a small set of hand-edited facts; everything else is generated.
The moment you hand-edit a derived number, the plan starts lying — and it lies
silently, because nothing recomputes.

This skill is distilled from a real 12-day, 2,050 km trip across northern
Spain in August. Its numbers are measured, not guessed — and *because* they
are measured, they belong to that trip: to its coastal roads, its latitude,
its month, its country's campsite pricing. The **method** transfers to Norway
in January or Arizona in July unchanged. The **numbers** do not, and the skill
keeps the two apart on sight.

## Method vs calibration

Two kinds of statement appear in this skill, typeset differently so you can
tell them apart at a glance.

**Method** is plain prose, and it holds anywhere: resolve anchored days
backwards; compute sunset from date and coordinates; prefer a `place` node to
a boundary centroid; account fuel tank to tank; simplify polylines
iteratively.

**Calibration** is one trip's measurement. It never appears bare in the
prose — it always sits in a tagged quote naming its origin:

> **⟨cal · N Spain, Aug 2026⟩** Trip-average speed **56 km/h**; a comfortable
> daily stage **150 km / 2 h 40 driving**.

The sorting rule: a measurement that *justifies a rule* (two routers agreeing
within 0.3 %, the 743 KB page that forced polyline simplification) is
**evidence** — it stays in the prose, because it argues and you don't
substitute it. A number you would *plug into a plan* — a speed, a ratio, a
price, a stop duration — is **calibration** and lives in a ⟨cal⟩ quote.
Anything inside a ⟨cal⟩ quote is the worked example, not a universal constant.
`reference/calibration.md` tells you how to measure your own replacement for
every one of them — most of it before you leave home.

Every trip also sets a handful of parameters the Spanish original hardcoded.
Declare them once, next to the data at the top of `stops.py`:

- **Timezone(s)**, as IANA names (`"America/Phoenix"`), per day if the trip
  crosses a zone boundary. Never a numeric offset — see Timing.
- **Geocoder country filter** (`countrycodes`), listing every country the
  trip touches.
- **Geofabrik regions** and **OSRM profile** for the router.
- **Presentation units and currency.** Storage is always metres, seconds and
  one currency; miles, gallons and mpg are formatting, applied at the edge.

`reference/calibration.md` shows the block.

## The pipeline

Keep one source of truth per kind of fact, and generate the rest:

```
stops.py      days and their stops (label, geocoding query)   ← hand-edited
      │       plus the trip parameters (tz, units, regions…)
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

| | Claude Code | Codex CLI | Chat and cloud |
|---|---|---|---|
| Shell | yes | yes | no / sandboxed |
| Docker, self-hosted router | yes | on approval | no |
| Outbound network | yes | **off by default** | assume none |
| Read files the user provides | yes | yes | yes |
| Write files for the user | yes | inside the workspace | yes |

The last column is claude.ai and Codex Cloud: a conversation with files but no
router. Codex Cloud does have a shell, but its network is blocked during the
agent phase unless the environment allowlists domains, and Docker-in-Docker is
not available there — treat it as the no-router tier until proven otherwise.

**Codex's sandbox, in one line:** the default is `workspace-write` with the
network *disabled*, so the first geocoding call fails until someone enables it
— `network_access = true` under `[sandbox_workspace_write]` in
`~/.codex/config.toml`, a per-domain allowlist, or approving the escalation
when Codex asks. Docker is a second gate: the daemon socket sits outside the
sandbox. Settle both **before** you start, not after half the stops are
geocoded — and for a 15-minute graph build, handing `scripts/osrm-up.sh` to
the user to run in their own terminal is usually faster than negotiating with
the sandbox.

So write the tool-dependent half to **degrade, not fail** — say which tier you
are on, and never present an estimate as if it were routed.

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
downloads any Geofabrik regions, builds with any profile, and serves. The
source trip's four Spanish regions: 354 MB of extracts → 1.7 GB graph, ~15 min
to build, **140 MB RAM** at rest. Cheap enough to leave running; budget disk at
roughly 5× the extract size.

**2. A public routing API.** Fine for one trip's worth of requests. Same
endpoints and the same lon,lat trap; mind the rate limit and the terms.

**3. No router at all.** Estimate from great-circle distance × a road/straight
ratio, at an average speed. Both numbers should be *yours*: the ratio can be
derived at a desk with nothing but a router and your stop coordinates, and the
speed from your first day of driving — both recipes are in
`reference/calibration.md`. If you have neither, borrow the source trip's as a
prior, and say you did.

> **⟨cal · N Spain, Aug 2026⟩** Road distance = **1.55 ×** straight line
> (median over 65 legs; p10 1.22, p90 2.36, one coastal cape 6.46 — the spread
> is the point). Speed **52 km/h** median per leg, **56 km/h** trip-wide.
> Motorway legs land near 1.2; coast and mountains are the worst case.

That is good enough to tell a two-hour day from a five-hour day, and to catch a
stage that obviously does not fit. **It is not good enough to schedule an
anchored appointment**, and you should say so rather than let a ±30% number
masquerade as a plan.

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

Constrain the geocoder to the trip's countries — `countrycodes` is a trip
parameter, comma-separated when the route crosses borders. Without it,
homonyms go transcontinental: Toledo, Paris and Santiago all exist on at
least two continents.

Tiered like the routing, and again: say which tier you used.

**1. LocationIQ, with a token the user provides.** Free tier, and measurably
the best of the cheap options — on the source trip's large Spanish
municipalities it returned the urban centre for 7 of 8 where Nominatim missed
by 2–4.5 km. **Offer it, don't assume it**: ask only when the trip has enough
city stops that kilometres of error per stop would move the departure times,
explain that it is free, and accept "no" without argument.

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
- **Snap-check every point** against the router's `/nearest`, and read the
  distances as a *relative* signal — rank your own stops and inspect the tail,
  because absolute thresholds reflect how densely mapped the region is. Capes
  and beaches snap far away legitimately — warn, never abort.
- **Cache by the full query string** and write the cache after every hit, not
  at the end of the run.

## Maps

Per-day inline SVG, drawn from the route geometry. See `reference/maps.md` for
the projection, the simplification and the URL formats.

Why inline SVG rather than a tile map: a strict Content-Security-Policy blocks
CDN tiles and Leaflet. Inline SVG needs no network, adapts to light and dark,
and weighs a few KB. Label the scale bar in the trip's presentation units —
the 1-2-5-10 sequence works in miles as well as kilometres.

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
light left** (a policy default, not a measurement — widen it when dark falls
fast or camp setup is slow), because arrival means "tent up", not "wheels
stopped".

**Sunset comes out of NOAA in UTC. Convert with an IANA timezone, never a
numeric offset.** The source trip's own code carried a hardcoded `TZ = 2` —
correct for Spain in summer, wrong at the first border, on the last Sunday of
October, and anywhere DST rules differ. `ZoneInfo("Europe/Madrid")` knows all
of that; a trip that crosses zones carries a timezone per day. Sum durations
in UTC seconds; format local at render time. `reference/timing.md` has the
conversion.

**Season and latitude change which constraint binds.** The source trip had
long August days, so sunset was a late, soft limit. In winter or at high
latitude, daylight is the budget: treat *every* day as anchored to sunset and
resolve backwards — and surface sunrise too, because the departure that falls
out may precede it. In the tropics sunset barely moves but twilight is short,
so the arrival margin bites harder. Above the polar circles the formula itself
tells you there is no sunset (or no sunrise) that day — handle it, don't
crash. All of it in `reference/timing.md`.

Sunset moves for two reasons you can compute: **4 minutes per degree of
longitude** (exact), and the seasonal drift, fastest near the equinoxes.
Twelve days eastbound across northern Spain in late August cost 36 minutes of
evening light.

Router times are **free-flow**. No router models traffic: add a surcharge in
peak season or at rush hour and say so in the plan — the skill's 10–15% is a
heuristic, not a measurement.

## Budget

**Find out how lodging bills before multiplying by nights.** Billing models
differ by country: Spanish campsites itemize per unit — adults + tent + car +
electricity — so listed prices run low; a typical North American campground
charges a flat rate per site, so the listed price may be the whole price. The
method is the same everywhere: price **one** night for your exact party before
trusting N × anything, and derive your correction from that receipt. Models
and the mechanics in `reference/budget.md`.

> **⟨cal · N Spain, Aug 2026⟩** 2 adults + tent + car: **31.35 €/night**
> average over 12 nights (range 19.95–44.00, VAT included). A 25 €/night
> estimate ran **24% low**. Electricity ~6 €/night rarely pays for itself in
> a tent.

**Fuel: account tank to tank, and inflate the distance.** Full at the start,
full at the end, sum what went in between. Two errors compound and push the
same way: a stale fuel price (check the current local one, never last trip's),
and the kilometres nobody plans — back to the campsite, hunting for parking,
wrong turns.

> **⟨cal · N Spain, Aug 2026⟩** Planned 1,798 km at 6.5 l/100 km and
> 1.70 €/l → 202 €. Actual **244.50 €, +21%**: about a third from the price
> being 1.78–1.86 €/l, the rest from ~250 unplanned km. **Real km ≈ planned
> × 1.14**; the consumption figure itself held.

Whatever the audience reads, compute in litres, kilometres and one currency —
the one you will pay in — and convert only at presentation. The conversions
are exact (1 mi = 1.609344 km; US mpg = 235.21 / (l/100 km); an imperial
gallon is 20% larger). Mixed-unit storage is where arithmetic goes to hide.

Budget the whole trip, then state what it excludes.

> **⟨cal · N Spain, Aug 2026⟩** Campsites 345 € + fuel 244.50 + tolls 15 +
> activities 183 ≈ **787 € for two, food excluded** (add 25–35 €/day cooking
> at the campsite).

## Deriving your own calibration

The most valuable thing this skill can hand you is not 56 km/h — it is the
recipe for *your* number. In order of when you can get them:

- **At the desk, before leaving:** the road/straight ratio (router + your
  stop coordinates, no driving involved); expected per-terrain speeds (the
  router's own durations); the whole trip's sunset table; the lodging billing
  model (one real quote); the current local fuel price.
- **On day 1:** your speed correction —
  `factor = actual driving seconds / routed seconds` — applied to every
  remaining leg, then regenerate clocks, departures and margins. Also your
  real tent-pitching time.
- **Only from the whole trip:** consumption (tank to tank) and the
  distance-inflation factor.

Recipes, code and the full source-trip table are in
`reference/calibration.md`. Where a number exists for the source trip but not
for your context — winter stage lengths, flat-rate campground averages — that
file says **unmeasured** and how to measure it, instead of offering a guess.
Extend it the same way.

## Keeping the plan alive

A plan is most useful *during* the trip, which means reconciling it with
reality every day: the price actually paid, the campsite actually used, the
hour you actually left. Record the real value, then **recompute** — do not
patch the rounded total, or the arithmetic drifts. Summing a corrected table
once caught a total that was one euro off and had been "fixed" by hand.

Reconciliation is also what keeps calibration honest: every recorded actual
updates the ratio between plan and reality, and the corrected plan predicts
tomorrow better than yesterday's did.

When a booking falls through, the honest move is to remove the stop and
re-route, not to leave it in the plan with a note. The times downstream are
wrong until you do.
