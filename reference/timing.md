# Timing a day

## Anchored vs free days

Every day resolves one of two ways:

**Anchored** — something happens at a fixed hour: a guided tour, a ferry, a
cave with timed entry. Resolve the departure time *backwards* from it, summing
only the legs and stops that fall before the anchor:

```python
departure = anchor_time - (drive_minutes_before + stop_minutes_before) / 60
```

Sum the actual legs. Do not estimate the offset — "we should leave around
nine" is how people miss tours.

**Free** — you pick the departure hour and resolve forwards.

Either way, finish with:

```python
arrival = departure + (drive_minutes + stop_minutes) / 60
margin  = sunset - arrival
```

and flag any day where `margin <= 0.5` h. **Arrival means the tent is up**, not
the engine off — build the pitching time into the day.

> **⟨cal · N Spain, Aug 2026⟩** Pitching: 45 min the first night, 35 the
> second, 25 once you have the hang of it. August figures, in daylight — a
> winter pitch in the dark is unmeasured; time yours on night 1.

## The day as a list of steps

Three step kinds cover everything, and they compose into a printable clock:

```
("t", destination, minutes, note)   consume the next routed leg, then stop here
("f", text,        minutes, note)   an event with no travel, at the current time
("h", text,        "HH:MM", note)   an event at a fixed hour — resets the clock
```

Walk the day with an iterator over that day's legs. A `"t"` step advances the
clock by the leg's duration, prints the *arrival* time, then advances again by
the stop's own duration. An `"h"` step sets the clock and does not add duration.

The mapping from `"t"` steps to legs is **positional**: the number of `"t"`
steps must equal the number of legs for that day. Assert it. When they drift
apart you get either a crash or, worse, a plausible clock built from the wrong
legs.

## Sunset (NOAA)

Needs only date, latitude and longitude. Accurate to the minute, which is far
beyond what trip planning requires.

```python
n      = d.toordinal() - date(2000, 1, 1).toordinal() + 0.0008
Jstar  = n - lon / 360
M      = (357.5291 + 0.98560028 * Jstar) % 360            # mean anomaly
C      = 1.9148*sin(M) + 0.02*sin(2*M) + 0.0003*sin(3*M)  # equation of centre
L      = (M + C + 180 + 102.9372) % 360                   # ecliptic longitude
Jtr    = 2451545.0 + Jstar + 0.0053*sin(M) - 0.0069*sin(2*L)
decl   = asin(sin(L) * sin(radians(23.44)))               # declination
cosw   = (sin(radians(-0.833)) - sin(lat)*sin(decl)) / (cos(lat)*cos(decl))
```

**Clamp before the acos.** At Arctic and Antarctic latitudes `cosw` leaves
[−1, 1] for part of the year, and that is the algorithm speaking, not an
error:

```python
if cosw < -1:   # midnight sun — no sunset today
if cosw >  1:   # polar night — no sunrise today
omega   = acos(cosw)
sunset  = Jtr + degrees(omega) / 360
sunrise = Jtr - degrees(omega) / 360
```

Report those days as what they are ("no sunset — light all night") instead of
crashing in Tromsø in June. The **-0.833°** solar altitude is not a fudge: it
accounts for atmospheric refraction and the sun's semidiameter, which together
are what "sunset" means to an observer.

## From UTC to the clock on the dashboard

`sunset` above is a Julian date — that is, **UTC**. Convert with an IANA
timezone and nothing else:

```python
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

sunset_utc   = (datetime(2000, 1, 1, 12, tzinfo=timezone.utc)
                + timedelta(days=sunset - 2451545.0))
sunset_local = sunset_utc.astimezone(ZoneInfo(day.tz))   # e.g. "America/Phoenix"
```

The rules, each of which was learned as a bug:

- **An IANA name, never a numeric offset.** This skill's own source code
  shipped with `TZ = 2` — correct for Spain between two Sunday mornings a year,
  wrong at the first border and wrong the week the clocks change. `zoneinfo`
  knows every region's DST rules, including the regions that have none
  (Arizona, most of the tropics).
- **Timezone is per-day config**, because trips cross zone boundaries — a
  border, or just a US state line, moves the dashboard clock an hour in the
  middle of a driving day. An anchor time is local *at the anchor*.
- **Sum in UTC seconds, format local at the edge.** Then a day that straddles
  a DST transition (23 or 25 local hours) resolves correctly with no special
  case: backward resolution from the anchor happens in UTC, and only the
  printed clock changes dialect.

## Sunset moves — for two computable reasons

- **Longitude**: exactly **4 minutes per degree** — westbound travel buys
  evening light, eastbound spends it. 1440 minutes over 360°; no measurement
  needed.
- **Season**: fastest near the equinoxes, near zero at the solstices, and
  stronger at higher latitude.

> **⟨cal · N Spain, Aug 2026⟩** Both effects pointing the same way: twelve
> days heading east in late August went from a 21:36 sunset on day one to
> 21:01 on day ten — 36 minutes of evening light gone.

Recompute sunset per stop per day. It costs nothing, and it is the only line
of the plan the sky refuses to renegotiate.

## Season and latitude change the planning regime

**Long days** (the source trip's regime — mid-latitude summer). Sunset is a
late, soft constraint; the margin check mostly catches over-stuffed days.
Everything in this skill's examples was written here.

**Short days** (winter, or high latitude in any season but summer). Daylight
becomes the budget, and the logic inverts: treat *every* day as anchored — the
anchor is `sunset − light_margin − pitch_time` — and resolve backwards. Surface
**sunrise** in the day clock too, because the departure that falls out of the
arithmetic may precede it. Driving after dark stops being an accident and
becomes a line item you chose and wrote down. Do not carry the summer
comfortable-stage figure into this regime; derive a new one on day 1
(`calibration.md`).

**Tropics.** Sunset is nearly constant across the whole trip and twilight is
short — the sun sets steeply, so usable light ends soon after the printed
hour. The drift check becomes a no-op; the arrival margin bites harder.
Compute per-stop anyway; it costs nothing.

**Polar circles.** The clamp above starts firing. In the no-sunset season the
margin check is vacuous — plan by fatigue, not light. In the no-sunrise season
every hour is "after dark" and the short-day regime applies in the extreme.

The ≥30 min light margin is a **policy default, not a measurement**. Widen it
where dark falls fast (tropics) or where arrival tasks slow down (winter camp
setup — unmeasured; time yours).

## Traffic

Router times are free-flow. Nothing in OSRM models congestion. Add a surcharge
in peak season or at rush hour and say so in the plan — a reader who knows the
number is optimistic can plan around it; one who doesn't will blame the plan.
The 10–15% this skill has used is a heuristic, not a measurement, and peak
season is a local fact: August on a Spanish coast road, ski weekends in an
alpine valley, Thanksgiving on a US interstate.
