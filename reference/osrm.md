# Self-hosted OSRM

## When it is worth it

Self-host when you will make more than a few dozen routing requests, want no
rate limits or API keys, or want the plan to work offline. Below that, a public
API is less trouble.

Measured cost for the source trip's four adjacent Spanish regions (Galicia,
Asturias, Cantabria, Castilla y León):

| | |
|---|---|
| Source extracts | 357 MB (4 files) |
| Merged PBF | 354 MB |
| Built graph | 1.7 GB on disk |
| Build time | ~15 min on 4 cores |
| RAM at rest | 140 MB |

MLD memory-maps its data, so resident memory stays small regardless of graph
size. Disk is the real constraint: on this build the graph came out at roughly
**5× the merged PBF**, which is the ratio to budget with before downloading.
Check extract sizes on the Geofabrik page first — a single US state or a
Nordic country can be a larger extract than four Spanish regions.

## Build

Extracts come from Geofabrik, at
`https://download.geofabrik.de/<path>-latest.osm.pbf`, where `<path>` is the
region's browse path — `europe/spain/galicia`, `north-america/us/arizona`,
`europe/norway`. Take the deepest extract that covers the route — a whole
country is several times larger for no benefit — and note that how deep the
subdivisions go varies by continent.

Merge adjacent regions with `osmium merge`. It deduplicates the nodes shared
along region borders; plain concatenation does not and produces a subtly
broken file.

```sh
docker run --rm -v "$PWD:/w" -w /w stefda/osmium-tool:latest \
  osmium merge a.osm.pbf b.osm.pbf c.osm.pbf -o merged.osm.pbf
```

Then the MLD pipeline — three passes, in this order:

```sh
IMG=ghcr.io/project-osrm/osrm-backend:latest
PROFILE=car     # or bicycle, foot
docker run --rm -v "$PWD:/data" $IMG \
  osrm-extract -p /opt/$PROFILE.lua /data/merged.osm.pbf   # slowest pass
docker run --rm -v "$PWD:/data" $IMG \
  osrm-partition /data/merged.osrm
docker run --rm -v "$PWD:/data" $IMG \
  osrm-customize /data/merged.osrm
```

`osrm-extract` takes a `.osm.pbf`; the other two take the `.osrm` base name.
Profiles ship inside the image at `/opt/`: `car.lua`, `bicycle.lua`,
`foot.lua`. The profile is a **trip parameter**, and it is baked into the
graph at extract time — switching profiles means rebuilding, so keep one graph
per profile. A custom `.lua` must be mounted into the container and referenced
by its mounted path.

Driving side needs no configuration: the profile reads it, along with speed
limits and access rules, from the OSM data itself. A graph of Britain or Japan
already drives on the left.

**MLD, not CH.** Contraction Hierarchies (`osrm-contract`) is faster to query
but far slower to build and cannot be re-customized. MLD lets you re-run
`osrm-customize` alone when traffic or penalties change. Both partition and
customize must have run, or the server refuses to start; the giveaway that a
graph is MLD is the presence of `.osrm.partition` and `.osrm.cells`.

## Serve

```sh
docker run -d --name osrm --restart unless-stopped \
  -p 127.0.0.1:5001:5000 -v "$PWD:/data" \
  ghcr.io/project-osrm/osrm-backend:latest \
  osrm-routed --algorithm mld --max-table-size 1000 /data/merged.osrm
```

The algorithm flag must match how the graph was built. Bind to `127.0.0.1` —
an open OSRM is an open compute endpoint for anyone who finds it.

## Endpoints

**One request per day, not per leg.** Pass every stop of the day as a
semicolon-separated coordinate list and OSRM returns one leg per consecutive
pair:

```
/route/v1/driving/{lon,lat};{lon,lat};…?overview=false&annotations=false
```

Coordinates are **lon,lat** — the opposite of the lat,lon everyone writes by
hand. Getting this backwards puts you in the sea; it is the single most common
mistake. `overview=false` skips the geometry when you only need numbers. (The
`/driving/` in the path is cosmetic — the served graph's profile decides what
is routed.)

Check `data["code"] == "Ok"` before reading anything: OSRM answers HTTP 200
with `"code": "NoRoute"`.

For a drawable line:

```
/route/v1/driving/{…}?overview=full&geometries=geojson
```

`geometry.coordinates` is a `[lon, lat]` list. It is dense — a 594 km route
returns 11,111 points — so simplify before drawing or embedding.

For validating a geocoded point:

```
/nearest/v1/driving/{lon},{lat}
```

Returns the distance to the nearest routable way and its name. The cheapest
bad-geocode detector there is: a good point snaps to a nearby named street, a
polygon centroid to a distant unnamed track (`geocoding.md` has the measured
distances and why to read them as a relative signal).

Distances and durations come back in **metres and seconds** regardless of
where the map is or who will read the plan. Keep them that way in `legs.json`
and convert to miles or local clock time only at presentation.

Use a 60 s timeout on `/route` and 20 s on `/nearest`. The first request after
startup is slow while the OS pages the graph in.
