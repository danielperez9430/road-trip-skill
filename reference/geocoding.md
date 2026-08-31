# Geocoding

The largest error in a trip plan. Routers agree with each other to within a
fraction of a percent; geocoders disagree by kilometres.

## Providers, in order

**LocationIQ** — optional, needs a free token, and it is measurably the best of
the cheap options. Checked against OSM `place` nodes via Overpass, it returned
the urban centre for **7 of 8** large municipalities where Nominatim returned
the polygon centroid and missed by 2–4.5 km (Vigo 4.3, Camariñas 4.5,
Ferrol 3.8).

```
GET https://eu1.locationiq.com/v1/search
    ?key=…&q=…&format=json&limit=10
    &countrycodes=es&normalizecity=1&namedetails=1
```

- `limit=10`, not 1 — you need the alternatives to run the containment check.
- `namedetails=1` returns every name variant, which is what makes the
  dropped-token check possible.
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
- Without requiring containment, a same-named town in another province wins.
  One stray "Vigo" stretched a leg from 240 to 319 km.

**Aim at a monument.** `"Catedral de León, León, España"` has no polygon and no
homonym. This is the single highest-leverage habit in the whole skill: it fixes
the problem in the *data* instead of the code. Write queries as specifically as
you can bear.

## Three checks that catch bad results

None of them should abort. They exist so a human looks.

**Bounding-box diagonal.** If it exceeds ~60 km, you probably matched a
province, not a town:

```python
diag = math.hypot((hi_lat - lo_lat) * 111, (hi_lon - lo_lon) * 111 * 0.74)
```

**Dropped query tokens.** Geocoders silently discard what they don't understand
and answer with confidence. Compare your query's tokens against *all* name
variants in `namedetails`, not just the display name: OSM keeps the local
toponym in `name` (Sotu Cangues, As Figueiras) and the Castilian one in
`name:es`. A strict comparison in Galicia or Asturias produces nothing but
false alarms.

**Snap distance**, via the router's `/nearest`. A town centre snaps within
~50 m of a named street; a polygon centroid snaps 300–600 m from an unnamed
forest track. Capes, beaches and mountain passes snap far away legitimately —
one real stop was 602 m from the nearest road and perfectly correct.

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
