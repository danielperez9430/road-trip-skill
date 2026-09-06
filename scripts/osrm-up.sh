#!/usr/bin/env bash
# Build and serve a local OSRM routing engine for a set of Geofabrik regions.
#
#   ./osrm-up.sh europe/spain/galicia europe/spain/asturias
#   ./osrm-up.sh north-america/us/arizona
#   PROFILE=bicycle PORT=5002 ./osrm-up.sh europe/norway
#
# Regions are Geofabrik browse paths — find yours at download.geofabrik.de and
# take the deepest extract that covers the route. Adjacent regions are merged.
#
# Tunables (environment):
#   PROFILE  routing profile baked into the graph: car (default), bicycle or
#            foot, which ship inside the OSRM image at /opt/. A custom .lua
#            needs a manual mount and is out of scope here.
#   PORT     host port to serve on (default 5001)
#   NAME     graph name (default "area"); use one NAME per profile/region set
#   DATA     working directory (default ./osrm-data)
#
# Needs Docker, outbound network and roughly 5x the extract size in disk. Under
# a sandboxed agent (Codex defaults to no network, and the Docker socket sits
# outside the sandbox) this is the one step worth running yourself in a real
# terminal — then point the agent at the server it leaves behind.
#
# Re-running with the graph already built skips straight to serving it — but
# only if the profile and regions match the ones it was built with; otherwise
# it refuses rather than silently serve the wrong graph. Delete
# $DATA/$NAME.osrm.* (and $DATA/$NAME.built) to force a rebuild.
set -euo pipefail

NAME=${NAME:-area}
DATA=${DATA:-$PWD/osrm-data}
PORT=${PORT:-5001}
PROFILE=${PROFILE:-car}
IMG=ghcr.io/project-osrm/osrm-backend:latest
OSMIUM=stefda/osmium-tool:latest

[ $# -gt 0 ] || { echo "usage: $0 <geofabrik/path> [more…]" >&2; exit 1; }
command -v docker >/dev/null || { echo "docker not found" >&2; exit 1; }

mkdir -p "$DATA/pbf"

# The profile and the region list are baked into the graph at extract time, so
# a cached graph is only valid for the exact combination it was built from.
stamp="$DATA/$NAME.built"
want=$(printf '%s\n' "$PROFILE" "$@")
if [ -f "$DATA/$NAME.osrm.partition" ] && [ -f "$stamp" ] \
   && [ "$(cat "$stamp")" != "$want" ]; then
  echo "graph '$NAME' was built from:" >&2
  sed 's/^/    /' "$stamp" >&2
  echo "but you asked for:" >&2
  printf '    %s\n' "$PROFILE" "$@" >&2
  echo "pick a different NAME, or delete $DATA/$NAME.osrm.* to rebuild." >&2
  exit 1
fi

if [ ! -f "$DATA/$NAME.osrm.partition" ]; then
  files=()
  for region in "$@"; do
    f="$DATA/pbf/$(basename "$region").osm.pbf"
    [ -f "$f" ] || {
      echo "==> downloading $region"
      curl -fL --progress-bar -o "$f" \
        "https://download.geofabrik.de/$region-latest.osm.pbf"
    }
    files+=("pbf/$(basename "$f")")
  done

  if [ ${#files[@]} -gt 1 ]; then
    # osmium merge, not cat: it deduplicates the nodes shared along region
    # borders. Concatenated PBFs are subtly broken.
    echo "==> merging ${#files[@]} extracts"
    docker run --rm -v "$DATA:/w" -w /w "$OSMIUM" \
      osmium merge "${files[@]}" -o "/w/$NAME.osm.pbf" --overwrite
  else
    cp "$DATA/${files[0]}" "$DATA/$NAME.osm.pbf"
  fi

  # MLD, not CH: slower to query, far faster to build, and osrm-customize can
  # be re-run alone afterwards. Both passes are mandatory or the server
  # refuses to start.
  echo "==> extract with $PROFILE.lua (this is the slow one)"
  docker run --rm -v "$DATA:/data" "$IMG" \
    osrm-extract -p "/opt/$PROFILE.lua" "/data/$NAME.osm.pbf"
  echo "==> partition"
  docker run --rm -v "$DATA:/data" "$IMG" osrm-partition "/data/$NAME.osrm"
  echo "==> customize"
  docker run --rm -v "$DATA:/data" "$IMG" osrm-customize "/data/$NAME.osrm"
  printf '%s' "$want" > "$stamp"
fi

docker rm -f "osrm-$NAME" >/dev/null 2>&1 || true
# Bound to localhost on purpose: an open OSRM is an open compute endpoint.
docker run -d --name "osrm-$NAME" --restart unless-stopped \
  -p "127.0.0.1:$PORT:5000" -v "$DATA:/data" "$IMG" \
  osrm-routed --algorithm mld --max-table-size 1000 "/data/$NAME.osrm"

# A test pair derived from the extract's own header bbox, so the hint works for
# any region on any continent. A NoRoute answer still proves the server is up —
# the bbox midpoint may be in the sea or off the road network.
pair="{lon},{lat};{lon},{lat}   # two points inside your regions"
if [ -f "$DATA/$NAME.osm.pbf" ]; then
  box=$(docker run --rm -v "$DATA:/w" -w /w "$OSMIUM" \
          osmium fileinfo -g header.boxes "/w/$NAME.osm.pbf" 2>/dev/null \
        | head -n1) || true
  if [ -n "${box:-}" ]; then
    derived=$(awk -v b="$box" 'BEGIN {
      gsub(/[()]/, "", b)
      if (split(b, c, ",") == 4) {
        lon = (c[1] + c[3]) / 2; lat = (c[2] + c[4]) / 2
        printf "%.4f,%.4f;%.4f,%.4f", lon - 0.05, lat, lon + 0.05, lat
      } }')
    [ -z "$derived" ] || pair=$derived
  fi
fi

echo "==> OSRM on http://127.0.0.1:$PORT"
echo "    test: curl -s 'http://127.0.0.1:$PORT/route/v1/driving/$pair?overview=false' | head -c 200"
