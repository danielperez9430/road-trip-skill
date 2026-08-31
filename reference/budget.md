# Budget

Both major line items are systematically underestimated, in ways that are
predictable enough to correct for up front.

## Campsites

Spanish campsites do not charge a flat pitch rate. They bill per unit and add
them up:

```python
def night(adult, tent, car, adults=2):
    if adult is None:          # flat rate: one price per pitch, all in
        return tent
    return adults * adult + tent + car
```

Electricity is billed separately, ~6 €/night, and rarely pays for itself in a
tent.

The price shown in search results is usually the pitch alone, which is why
estimates come in low. Measured over twelve August nights, two adults with a
tent and a car:

| | |
|---|---|
| Average | **31.35 €/night** |
| Range | 19.95 – 44.00 € |
| Initial estimate | 25 €/night — **24% low** |

Regional spread is real: Galicia was consistently cheaper than eastern
Asturias and Cantabria.

Track which prices are **verified** and which are estimates, and show it. A
budget that hides the difference invites false confidence.

## Fuel

Two independent errors compound, and both push the same way.

Planned: 1,798 km at 6.5 l/100 km and 1.70 €/l → **202 €**.
Actual: **244.50 €**, +21%.

The split matters, because it tells you which knob to turn:

- **Price**: paid 1.78–1.86 €/l against 1.70 estimated. About 12 cents/l, ~16 €,
  a third of the overrun. Check the current regional average rather than
  reusing a number from a previous trip.
- **Distance**: roughly 250 km that no planner counts — driving back to the
  campsite, hunting for parking, wrong turns, the detour to the supermarket.
  This is the bigger half.

So: **real km ≈ planned km × 1.14**, and the consumption figure itself was
accurate. 6.5 l/100 km held up.

Account **tank to tank**: full at the start, full at the end, sum what you put
in between, and exclude the initial fill (you did not burn it on this trip).
Anything else double-counts or misses the last leg.

## Presenting it

Sum the table; never patch a rounded total. Recomputing once caught a total
that was a euro off after being "corrected" by hand.

State what the number excludes. The example trip:

| Item | € |
|---|---|
| Campsites (12 nights) | 345 |
| Fuel | 244.50 |
| Tolls | 15 |
| Activities and entries | 183 |
| **Total, two people, food excluded** | **≈ 787** |

Add 25–35 €/day for two, cooking at the campsite. Eating out is a different
trip and a different budget.
