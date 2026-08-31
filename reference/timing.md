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
the engine off — build the pitching time into the day (45 min the first night,
35 the second, 25 once you have the hang of it).

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
omega  = acos((sin(radians(-0.833)) - sin(lat)*sin(decl)) / (cos(lat)*cos(decl)))
sunset = Jtr + degrees(omega) / 360
```

The **-0.833°** solar altitude is not a fudge: it accounts for atmospheric
refraction and the sun's semidiameter, which together are what "sunset" means
to an observer.

Convert to local time with the summer offset, and remember it changes if the
trip crosses a DST boundary.

Sunset drifts more than people expect. Twelve days heading east across northern
Spain in late August: 21:36 on day one, 21:01 on day ten — 36 minutes of
evening light gone.

## Traffic

Router times are free-flow. Nothing in OSRM models congestion. In August or at
rush hour, add **10–15%** and say so in the plan — a reader who knows the number
is optimistic can plan around it; one who doesn't will blame the plan.
