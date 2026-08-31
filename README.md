# road-trip

A [Claude Code](https://claude.com/claude-code) skill for planning multi-day
driving trips: real routing, departure times that work backwards from a fixed
appointment, sunset-aware arrivals, offline per-day maps, and budgets
calibrated against what a trip actually costs.

It is distilled from a real 12-day, 2,050 km trip across northern Spain
(Galicia → Asturias → Cantabria → León), planned and then continuously
reconciled against reality as it happened. **Every number in it is measured,
not guessed** — including the ones that show the original estimates were wrong.

## Install

```sh
git clone https://github.com/danielperez9430/road-trip-skill \
  ~/.claude/skills/road-trip
```

Claude Code picks it up on the next session. Ask for it by name (`/road-trip`)
or just describe the task — planning a route, estimating fuel, working out what
time to leave — and it loads on its own.

## What's inside

| File | |
|---|---|
| `SKILL.md` | The skill: pipeline, routing, geocoding, maps, timing, budget |
| `reference/osrm.md` | Self-hosting OSRM: build, serve, endpoints, sizing |
| `reference/maps.md` | Projection, polyline simplification, navigation URLs |
| `reference/timing.md` | Anchored vs free days, NOAA sunset, traffic |
| `reference/budget.md` | Campsite and fuel models, with real figures |
| `scripts/osrm-up.sh` | Builds and serves a local OSRM for any Geofabrik regions |

## A few things it will save you

**Geocoding is the error that matters, not routing.** Two independent routers
agreed to within 0.3% over 1,800 km. Geocoding was off by 2–4.5 km, because a
municipality's boundary centroid sits nowhere near its town centre. "León"
lands 34 km from the cathedral.

**Campsites bill per unit, not per pitch.** Budgeting 25 €/night came in 24%
low. The real average was 31.35 € for two adults, a tent and a car.

**Real distance ≈ planned × 1.14.** Roughly 250 km of the trip were the
unplannable kind: back to the campsite, hunting for parking, wrong turns. That,
plus fuel costing more than estimated, put the fuel bill 21% over budget.

**Waze cannot import a route.** Neither can the phone apps import GPX. A Google
Maps directions URL with `%7C`-joined waypoints is the only thing that will
navigate a whole multi-stop day, and it caps out at 9 intermediate stops.

**Ramer–Douglas–Peucker must be iterative.** The recursive form overflows the
stack at 6,000 points — which is what one day of raw route geometry looks like.
Unsimplified, twelve day-maps weighed 743 KB; at a 0.4 px tolerance, 190 KB.

## Running the router

```sh
./scripts/osrm-up.sh europe/spain/galicia europe/spain/asturias
```

Downloads the Geofabrik extracts, merges them with `osmium`, runs the OSRM MLD
pipeline and serves it on `127.0.0.1:5001`. Four Spanish regions cost 1.7 GB of
disk, ~15 minutes to build, and 140 MB of RAM at rest.

Requires Docker. Nothing else.

## Scope

Written around Spain and Western Europe: Geofabrik extracts, `car.lua`, euros,
CEST. The method transfers anywhere; the calibration constants are honest about
where they came from.

## License

MIT — see [LICENSE](LICENSE).
