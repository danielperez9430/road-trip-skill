# Budget

Both major line items get systematically underestimated. The *mechanisms*
travel to any country; the *sizes* below are one trip's measurement, tagged as
such.

## Lodging: find the billing model, then multiply

The number in search results is rarely the number on the receipt — but *why*
differs by country, and so does the direction of the error:

- **Per-unit, itemized** (Spain, much of Europe): N adults + tent + car +
  electricity, summed. The listed price is often the pitch alone, so
  estimates run **low**.
- **Flat per site** (typical of North American state and national
  campgrounds): one price covers the party up to a vehicle/person limit. The
  listed price may be the whole price — and applying a per-unit correction on
  top of it fabricates an overrun that never happens.
- **Add-ons appear everywhere**: extra vehicle, extra person above N, coin
  showers, city/tourist tax added at checkout, dynamic season pricing at
  private grounds.

The method is the same in every model: **price one real night for your exact
party** — a booking page taken to the final screen, or an email quote — before
multiplying anything by N nights. Receipt ÷ listed price is your correction
factor for that country or chain, and for nothing else.

A billing function that covers both models:

```python
def night(adult, tent, car, adults=2):
    if adult is None:          # flat rate: one price per site, all in
        return tent
    return adults * adult + tent + car   # per-unit, itemized
```

> **⟨cal · N Spain, Aug 2026⟩** Twelve August nights, two adults + tent +
> car, per-unit billing: average **31.35 €/night**, range 19.95–44.00, VAT
> included. The initial 25 €/night estimate ran **24% low**. Electricity,
> billed apart at ~6 €/night, rarely pays for itself in a tent. Regional
> spread was real: Galicia consistently cheaper than eastern Asturias and
> Cantabria.

Track which prices are **verified** and which are estimates, and show it. A
budget that hides the difference invites false confidence.

## Fuel

Two independent errors compound, and both push the same way:

- **Price.** Use the current local price for your region, grade and unit, from
  a national price tracker — never a number remembered from a previous trip.
- **Distance.** Kilometres no planner counts: driving back to the campsite,
  hunting for parking, wrong turns, the detour to the supermarket. They accrue
  every day and only show up summed.

> **⟨cal · N Spain, Aug 2026⟩** Planned 1,798 km at 6.5 l/100 km and
> 1.70 €/l → **202 €**. Actual **244.50 €, +21%**: ~16 € of it from paying
> 1.78–1.86 €/l, the larger rest from ~250 unplanned km. So **real km ≈
> planned × 1.14** — and the consumption figure itself held: 6.5 l/100 km,
> planned and measured.

The ×1.14 is a prior about *drivers*, not about Spain — replace it with your
own trip-end measurement (`calibration.md`).

Account **tank to tank**: full at the start, full at the end, sum what you put
in between, and exclude the initial fill (you did not burn it on this trip).
Anything else double-counts or misses the last leg.

## Units and currency

Store and compute in **one** system — litres, kilometres, l/100 km — and in
**one** currency, the one you will actually pay in. Convert only at
presentation, with exact factors:

- 1 mile = 1.609344 km, exactly.
- US mpg = **235.21 / (l/100 km)** — so the conversion is a reciprocal, and
  "half the consumption" means "double the mpg", which trips people up in
  both directions.
- An **imperial gallon is 20% larger** than a US gallon; UK mpg figures run
  ~1.2× the US figure for the same car. Never mix the two in one table.

If the reader budgets in a different currency, convert the **total, once, at
the end**, and date the exchange rate next to it. Converting line by line
buries rounding errors in every row.

## Presenting it

Sum the table; never patch a rounded total. Recomputing once caught a total
that was a euro off after being "corrected" by hand.

State what the number excludes. The source trip, as the worked example:

> **⟨cal · N Spain, Aug 2026⟩**
>
> | Item | € |
> |---|---|
> | Campsites (12 nights) | 345 |
> | Fuel | 244.50 |
> | Tolls | 15 |
> | Activities and entries | 183 |
> | **Total, two people, food excluded** | **≈ 787** |
>
> Food added 25–35 €/day for two, cooking at the campsite.

Tolls deserve one warning outside Spain: several European countries bill by
**vignette** — per time window, not per kilometre — which changes the
arithmetic from a per-leg cost to a flat trip cost. Look up the model for each
country you cross; it is a five-minute check.

Eating out is a different trip and a different budget.
