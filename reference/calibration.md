# Calibration

Every number you can plug into a plan, where it came from, and how to replace
it with your own. The method files (`timing.md`, `budget.md`, …) tell you
*what* to compute; this one tells you *which constants* feed the computation
and how to measure them for your trip.

The convention, restated: anything in a **⟨cal⟩** quote is one trip's
measurement — here, 12 days and 2,050 km across northern Spain in August,
right-hand traffic, metric, euros, long days. Use it as a prior when you have
nothing, replace it the moment you have anything.

## The trip configuration

Everything the Spanish original hardcoded, declared once at the top of
`stops.py`. `None` is not a placeholder to fill with a guess — it is a task:

```python
TRIP = {
    "tz":           "Europe/Madrid",  # IANA name, never a numeric offset;
                                      # a list per day if the trip crosses zones
    "countrycodes": "es",             # geocoder filter; comma-separated
                                      # for a multi-country route ("fr,es")
    "regions":      ["europe/spain/galicia",
                     "europe/spain/asturias"],   # Geofabrik paths
    "profile":      "car",            # OSRM profile; baked into the graph
    "units":        "metric",         # presentation only — storage is m/s/SI
    "currency":     "EUR",            # the one you will actually pay in
    "fuel_price":   None,             # measure: current local price
    "consumption":  None,             # measure: your car, tank to tank
    "road_ratio":   None,             # derive at the desk (below)
    "trip_speed":   None,             # derive at the desk; correct on day 1
}
```

Driving side is deliberately absent: the OSRM profile reads it from the OSM
data, so routing needs no flag. Where it *does* show up is in your own
measured speeds if you are driving on the unfamiliar side — which is one more
reason the day-1 correction below exists.

## At the desk, before leaving

### Road/straight ratio

Needs a router and your stop coordinates — no driving. Route every leg, divide
by the great-circle distance, take the median and the spread:

```python
import math

def great_circle_km(a, b):                     # a, b = (lon, lat)
    la1, la2 = math.radians(a[1]), math.radians(b[1])
    h = (math.sin((la2 - la1) / 2) ** 2
         + math.cos(la1) * math.cos(la2)
           * math.sin(math.radians(b[0] - a[0]) / 2) ** 2)
    return 2 * 6371.0 * math.asin(math.sqrt(h))

ratios = sorted(leg["km"] / great_circle_km(a, b)
                for (a, b), leg in zip(pairs, legs))
n = len(ratios)
median, p10, p90 = ratios[n // 2], ratios[n // 10], ratios[9 * n // 10]
```

Report the spread, not just the median — the spread is what tells you whether
tier-3 estimating is usable at all on your terrain.

> **⟨cal · N Spain, Aug 2026⟩** Over 65 coastal and mountain legs: median
> **1.55**, p10 1.22, p90 2.36, one coastal cape 6.46. Motorway legs near 1.2.

### Expected speeds, per terrain

The router already predicts them: `leg["km"] / (leg["seconds"] / 3600)`.
Group by a terrain label you assign per leg (coast, mountain, motorway) —
those groups are what you will correct separately on day 1. Remember router
times are free-flow.

> **⟨cal · N Spain, Aug 2026⟩** Actual, measured: mixed roads **56 km/h**,
> coastal **48**, motorway **61**; 52 km/h median per individual leg.

### The sunset table

Pure computation — date, lat, lon per stop, NOAA (`timing.md`). Do it for the
whole trip before leaving: it is the cheapest way to discover that your
February itinerary has seven-hour days, before the itinerary is booked.

### Lodging billing model

Price **one real night** — a booking page or an email quote — for your exact
party, and compare it with the listed search price. The ratio between the two
is your correction for that country or chain. Do not transplant another
country's correction; `budget.md` has the known models and why they differ.

### Fuel price

The current local number for your region and grade, from any national price
tracker, in the local unit and currency. Never a remembered one.

> **⟨cal · N Spain, Aug 2026⟩** Estimated 1.70 €/l from memory; paid
> 1.78–1.86. That gap alone was a third of a 21% fuel overrun.

## On day 1

Day 1 is the calibration day. Three measurements, all free:

**Speed correction.** Engine-on driving time only, stops excluded:

```python
factor = actual_driving_seconds / routed_seconds     # day 1
for leg in remaining_legs:
    leg["seconds"] *= factor
# then regenerate: day clocks, departure times, sunset margins
```

One day is a small sample — a single traffic jam pollutes it. From day 2 on,
use the cumulative trip-wide ratio rather than yesterday's alone, and keep
separate factors per terrain group if the trip mixes coast and motorway.

**Pitch time.** Time it, tent-out to tent-up.

> **⟨cal · N Spain, Aug 2026⟩** 45 min the first night, 35 the second,
> 25 once practised — August, daylight, mild weather. Nobody has timed a
> winter pitch in the dark for this skill. If that is your trip: measure it
> night 1 and multiply it through the remaining margins.

**First receipt** against the estimate. It updates the lodging correction with
a real data point in your actual country.

## Only from the whole trip

**Consumption** needs tank-to-tank accounting: full at the start, full at the
end, sum the fills in between, exclude the initial fill. Anything shorter is
noise.

**Distance inflation** — real odometer km ÷ planned km — needs the whole trip,
because the unplanned kilometres (back to the campsite, parking hunts, wrong
turns) accrue daily but only mean something summed.

> **⟨cal · N Spain, Aug 2026⟩** Real km = planned × **1.14** (~250 km nobody
> planned, over 1,798 planned). Consumption 6.5 l/100 km, and it held —
> planned and measured agreed.

Both are properties of *you, your car and your style* more than of the region,
so they are the most transplantable numbers here — from your own previous
trips, not from this table.

## The source trip, in full

> **⟨cal · N Spain, Aug 2026⟩** — 12 days, 2,050 km, two adults, tent, car,
> right-hand traffic, long days.
>
> | Quantity | Value |
> |---|---|
> | Average speed, mixed roads | 56 km/h |
> | Average speed, coastal road | 48 km/h |
> | Average speed, motorway | 61 km/h |
> | Road / straight-line ratio | 1.55 median (p10 1.22, p90 2.36) |
> | Comfortable daily stage | 150 km / 2 h 40 driving |
> | "Long day" (worth flagging) | 5 h 54 driving |
> | Pitching a tent | 45 min day 1, 35 day 2, 25 thereafter |
> | Lunch stop | 90 min (75–120) |
> | Viewpoint / cape | 30–45 min |
> | Large beach | 60–180 min |
> | Museum or cave | 90–150 min |
> | Town you pass through | 0 min — name what to see, or don't stop |
> | Campsite, per-unit billing | 31.35 €/night avg (19.95–44.00) |
> | Campsite estimate bias | 25 €/night guessed → 24% low |
> | Fuel consumption | 6.5 l/100 km (planned = measured) |
> | Fuel price | 1.78–1.86 €/l paid vs 1.70 guessed |
> | Real vs planned distance | × 1.14 |
> | Traffic surcharge (heuristic, unmeasured) | +10–15% |

Two entries are policy rather than measurement and travel better: the ≥30 min
light margin before sunset, and "a town you pass through gets 0 minutes unless
you can name what to see". Keep them unless your season argues otherwise
(`timing.md`).

## Unmeasured — measure, don't guess

Contexts this skill has **no numbers for**. The honest output for each is
"unmeasured, here is the procedure", never a filled-in estimate:

- **Winter / high-latitude driving.** Comfortable stage, speeds on snow,
  margin needed after dark. Measure: sunset table at the desk (that part is
  free), then treat day 1 as pure calibration with generous slack, and expect
  the summer stage figure not to transfer.
- **Camp setup in cold or darkness.** Time night 1, propagate.
- **Flat-rate campground averages** (North America, Australia, elsewhere).
  Measure: one real quote per park system or chain before multiplying — state
  and national park systems publish rates, private grounds price dynamically.
- **Left-hand-traffic effect on your speeds**, for a driver used to the right
  (or vice versa). Routing needs nothing; your day-1 speed factor captures it.
- **Tolls outside Spain.** Look them up per road; vignette countries bill per
  time, not per km, which changes the arithmetic.
- **Tropical twilight.** Sunset is stable but usable light after it is short;
  if arrival margins matter, note actual dark-time on day 1.

When you measure one of these, record it as a new ⟨cal⟩ block with its own
origin tag — that is how this file grows without ever lying.
