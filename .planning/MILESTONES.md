# Milestones

## v0.9 — Pre-release (Baseline)

**Completed:** 2026-04-05 (established as baseline from existing codebase)

**What shipped:**
- Coin Sort mode: 3x5 grid, bag-based dealing, 5-color merge mechanics
- Merge Arena: 7x8 grid, 12 item chains, generators, 10 levels of orders
- Skill tree: 30 nodes, PoE2-style interconnected graph
- Cross-mode economy: Fuel, Stars, Bags, Drops, Chests
- Arena tutorial (18-step state machine)
- Per-session commissions (2 per CS game)
- Yandex Games SDK (interstitial + rewarded ads)
- Save/load persistence
- Web build via love-web-builder (Emscripten/WASM)

**What we learned:**
- Particle system causes web performance issues
- Tutorial needs to be more guided (players get lost)
- Per-session commissions lose progress on exit
- Dead code from scrapped classic mode still in repo
