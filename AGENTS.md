# road-trip

This repository is a skill, not an application: a method for planning
multi-day driving trips — real routing, departure times resolved backwards
from a fixed appointment, sunset-aware arrivals, offline per-day maps, and
budgets calibrated against what a trip actually costs.

**The instructions are in `SKILL.md`.** Read it before routing, scheduling or
budgeting anything. It links the files under `reference/` and says which one to
open for which question — read them one at a time, when the task needs them,
not all at once.

Two habits the rest of the skill depends on:

- **Method and calibration are kept apart.** Prose is universal; every number
  measured on one specific trip is quarantined in a quote tagged
  `⟨cal · N Spain, Aug 2026⟩`. Never promote one of those numbers to a general
  rule, and never invent a replacement — `reference/calibration.md` says how to
  measure your own, and says "unmeasured" where no honest number exists.
- **The plan is a program.** Hours, distances and costs are derived from a
  small set of hand-edited facts. Fix the generator, never the generated file.

If you are running under a sandbox, settle this first: routing and geocoding
need outbound network, and `scripts/osrm-up.sh` needs Docker plus roughly five
times the map extract in disk. Codex disables the network by default. Ask for
what you need up front — and if you cannot have it, say which tier you are on
and use the documented fallback, which estimates out loud rather than
pretending to have routed.
