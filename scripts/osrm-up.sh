#!/usr/bin/env bash
# Build and serve a local OSRM routing engine for a set of Geofabrik regions.
#
#   ./osrm-up.sh europe/spain/galicia europe/spain/asturias
#
# Re-running with the graph already built skips straight to serving it.
# Delete $DATA/$NAME.osrm.* to force a rebuild.
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
  echo "==> extract (this is the slow one)"
  docker run --rm -v "$DATA:/data" "$IMG" \
    osrm-extract -p "/opt/$PROFILE.lua" "/data/$NAME.osm.pbf"
  echo "==> partition"
  docker run --rm -v "$DATA:/data" "$IMG" osrm-partition "/data/$NAME.osrm"
  echo "==> customize"
  docker run --rm -v "$DATA:/data" "$IMG" osrm-customize "/data/$NAME.osrm"
fi

docker rm -f "osrm-$NAME" >/dev/null 2>&1 || true
# Bound to localhost on purpose: an open OSRM is an open compute endpoint.
docker run -d --name "osrm-$NAME" --restart unless-stopped \
  -p "127.0.0.1:$PORT:5000" -v "$DATA:/data" "$IMG" \
  osrm-routed --algorithm mld --max-table-size 1000 "/data/$NAME.osrm"

echo "==> OSRM on http://127.0.0.1:$PORT"
echo "    test: curl -s 'http://127.0.0.1:$PORT/route/v1/driving/-8.72,42.24;-3.80,43.46?overview=false' | head -c 200"
