# Geocoding

The largest error in a trip plan. Routers agree with each other to within a
fraction of a percent; geocoders disagree by kilometres.

## Providers, in order

**LocationIQ** — optional, needs a free token, and it is measurably the best of
the cheap options. Checked against OSM `place` nodes via Overpass on the
source trip, it returned the urban centre for **7 of 8** large Spanish
municipalities where Nominatim returned the polygon centroid and missed by
2–4.5 km (Vigo 4.3, Camariñas 4.5, Ferrol 3.8). The mechanism it fixes —
boundary centroids standing in for towns — is structural to OSM, not Spanish.

```
GET https://eu1.locationiq.com/v1/search
    ?key=…&q=…&format=json&limit=10
    &countrycodes={trip}&normalizecity=1&namedetails=1
```

- `countrycodes` is a **trip parameter**, not a constant: the ISO codes of
  every country the route touches, comma-separated (`fr,es`). Leaving it off
  invites transcontinental homonyms — Toledo, Paris and Santiago all exist on
  at least two continents. Setting it to only the first country silently
  loses every stop past the border.
- `limit=10`, not 1 — you need the alternatives to run the containment check.
- `namedetails=1` returns every name variant, which is what makes the
  dropped-token check possible.
- `accept-language` pins display names to one language, which keeps the
  token comparison stable run to run.
- **404 means "no results"**, not an error. 429 means quota.
- 2 req/s, 5,000/day on the free tier. Sleep 0.6 s between calls.
- Retry 429 with a linear backoff (`sleep 2 * attempt`, 4 attempts).

**Nominatim** — no token, no signup, and it is the fallback rather than the
default because it answers city queries with polygon centroids. Usage policy
is 1 req/s and a real, identifying `User-Agent`; it is enforced socially, so
respect it or you get the whole project blocked for everyone.

**Neither** — ask the user for coordinates, or accept the place names and say
clearly that you could not verify them.

## Asking for the token

Only ask when it buys something: a plan with a dozen city stops, where 3 km of
error per stop compounds into wrong departure times. For a handful of
already-precise queries, Nominatim is fine and asking is noise.

Say what it is for and that it is free. Then treat it as a secret:

- Read it from an environment variable (`LOCATIONIQ_TOKEN`) or a gitignored
  secrets file. Never a literal in code.
- Never write it into generated output — not the HTML, not a cache, not a
  committed config, not a log line.
- Never echo it back in conversation, and do not put it in a file you are about
  to show or publish.
- If the user pastes one into a chat, use it for that session and do not
  persist it anywhere they did not ask for.

Work without it if the user would rather not hand one over. The skill degrades
to Nominatim; say that the coordinates are less precise and move on.

## Picking the right result

Ask for several results and choose deliberately.

**If the top hit is a `boundary`, look for a `place` node inside its bounding
box.** Two separate failures, one check:

- A boundary centroid is the geometric middle of a municipality. "León" lands
  34 km from the cathedral, in a field.
- Without requiring containment, a same-named town elsewhere wins. One stray
  "Vigo" stretched a leg from 240 to 319 km — and that was *with* a country
  filter; without one the wrong Vigo can be in Italy.

**Aim at a monument.** `"Catedral de León, León, España"` has no polygon and no
homonym. This is the single highest-leverage habit in the whole skill: it fixes
the problem in the *data* instead of the code. Write queries as specifically as
you can bear — it works in any country, and in countries with strong street
addressing a full address does the same job.

## Three checks that catch bad results

None of them should abort. They exist so a human looks.

**Bounding-box diagonal.** If it exceeds ~60 km, you probably matched an
administrative region, not a town:

```python
diag = math.hypot((hi_lat - lo_lat) * 111, (hi_lon - lo_lon) * 111 * 0.74)
```

(The 0.74 is cos of the source trip's ~42° latitude — recompute it for yours,
it is one line.)

**Dropped query tokens.** Geocoders silently discard what they don't understand
and answer with confidence. Compare your query's tokens against *all* name
variants in `namedetails`, not just the display name: OSM keeps the local
toponym in `name` and other languages in `name:xx`. A strict comparison
produces nothing but false alarms anywhere the map's language differs from
your queries — Galicia and Asturias on the source trip (Sotu Cangues, As
Figueiras), but equally Wales, Flanders, Québec or most of India.

**Snap distance**, via the router's `/nearest`. A point in a town snaps to a
named street close by; a polygon centroid snaps to some unnamed track far
away. Capes, beaches and mountain passes snap far away legitimately — one
real stop was 602 m from the nearest road and perfectly correct.

> **⟨cal · N Spain, Aug 2026⟩** Town centres snapped within ~50 m of a named
> street; polygon centroids 300–600 m from unnamed forest tracks.

Those thresholds reflect Spanish OSM density. In sparsely mapped country
everything snaps farther, so read snap distance as a **relative** signal:
rank your own trip's stops by it and inspect the tail, rather than applying
50 m as a universal cutoff.

## Caching

Cache to disk **after every successful lookup**, not at the end of the run. A
crash halfway through an 80-stop trip should not throw away the work, and
geocoding is the slow, rate-limited part.

Key by the **full query string**, not the short label. Some stops have display
names that never appear in their own query, and two different stops can share a
label.

Store enough to audit later, not just the coordinates:

```json
{
  "Vigo, Pontevedra, España": {
    "lon": -8.7207, "lat": 42.2328,
    "display": "Vigo, Galicia, España",
    "osm_class": "place",
    "source": "locationiq",
    "snap_m": 12, "snap_via": "Rúa de Urzáiz"
  }
}
```

Keep a manual-override table for the handful of places every geocoder gets
wrong, and mark those entries so they are obviously not machine-derived.
