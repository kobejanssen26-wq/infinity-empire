# ECLIPSE: INFINITE EMPIRE

A grind-focused Roblox simulator/tycoon: build a factory, hatch and fuse creatures, automate, research,
rebirth. Written in Luau, organised as a [Rojo](https://rojo.space) project (the repo was empty, so the
whole project structure here is new).

## Run it in Roblox Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (7.x) and its Studio plugin.
2. `rojo build -o Eclipse.rbxlx` then open `Eclipse.rbxlx` in Studio - **or** `rojo serve` and click *Connect* in the plugin on an empty Baseplate place.
3. Delete the template Baseplate and SpawnLocation if you used one (the server builds its own ground).
4. Press **Play** (or *Start Server + 2 players* to see multiple plots).
5. **Persistence in Studio:** *Game Settings > Security > Enable Studio Access to API Services*, and the place must be
   published (File > Publish to Roblox). Without that, the server prints a warning and uses a temporary profile
   (nothing is saved) - gameplay still works.

### Playing
Walk to a machine and press **E** to build/upgrade it, or use the left menu: **Factory**, **Creatures**, **Eggs**
(eggs / fusion / store), **Research**, **Rebirth**, **Quests**, **Index**, **Ranks**, **Settings**.
The tracker at the bottom walks you through a 9-step tutorial.

## Project layout

```
default.project.json            Rojo mapping
src/shared/   (ReplicatedStorage.Shared)   data + pure rules used by BOTH sides
  Config, Machines, Creatures, Research, Prestige, Quests, Monetization   <- all content/tuning is data
  Formulas (costs/scaling), Stats (derives every multiplier & rate), Format, Remotes
src/server/   (ServerScriptService.Server)
  Logic/Engine.lua     ALL game rules, pure Luau (no Roblox services) -> unit-testable
  Logic/Shared.lua     the one place server code reaches ReplicatedStorage modules
  Services/            DataService (DataStore+lock+autosave), PlotService (procedural factory),
                       Router (the only client entry point), Session (replication/announcements),
                       PurchaseService (Robux), LeaderboardService
  Main.server.lua      bootstrap + one Heartbeat loop for all players
src/client/   (StarterPlayerScripts.Client)
  Main.client.lua      HUD, navigation, page manager, notifications
  State/UI/Common/Theme, Pages/*   one module per screen
tests/ tools/          see "Testing"
```

### Security model
* The client can only call `Request:InvokeServer(action, args)`. `Router` rate-limits (token bucket), whitelists
  the action, type-checks args, then calls `Engine`, which re-validates every rule (ownership, cost, caps, zone,
  prerequisites, exclusivity). The client never sends amounts of currency, only *which* thing to buy.
* Resources, drops, mutation rolls and rewards are all computed on the server (`Engine`, `Random`).
* Robux grants happen only in `PurchaseService` (`ProcessReceipt` is idempotent per `PurchaseId`, confirms only after a
  successful save; gamepass ownership comes from Roblox events/`UserOwnsGamePassAsync`). IDs of `0` mean "not configured"
  and cannot be bought.
* DataStore: `UpdateAsync` session locks (a server never overwrites a profile owned by another live server),
  retry with backoff, autosave every 60s, save on leave and in `BindToClose`.
* Trading/stealing are intentionally **not** implemented. Visiting is view-only (teleport next to a plot);
  ProximityPrompts only act for the plot owner.

## Game systems (all functional and connected to the economy)
* **Resources:** Cash, Biomass, Cores (research), Echoes (rebirth). Values are clamped at 1e15.
* **6 machines** (`Machines.lua`): Ember Forge, Hydraulic Press, Bio-Lab, Core Reactor, Mutation Chamber, Quantum Assembler -
  level upgrades with milestone doublings, slots that unlock by level, element compatibility with creatures.
* **4 factory zones** that unlock machines/eggs and visibly upgrade the plot (pillars + lamps, glass roof, neon trim, sky ring).
* **18 creatures, 6 rarities, 5 mutation variants, 4 genetic traits, 4 eggs with odds + pity, 14 fusion recipes**
  (mythic is fusion-only), creature levels (Biomass), a collection Index with discovery rewards and server-wide
  announcements for rare discoveries (cross-server via MessagingService).
* **Research:** 5 branches, 24 nodes, prerequisites, *exclusive* specialisations, automation unlocks (Auto-Upgrader, Smart Assignment).
* **Rebirth:** requirement grows 3x per rebirth, Echoes reward, Echo shop (6 upgrades), explicit confirmation dialog that lists
  what is lost / kept / gained.
* **Quests:** 9-step tutorial, 3 daily quests (rolled per UTC day), repeatables, milestones, 10 achievements (auto-granted),
  rotating limited-time events (`Quests.events`) and a cooperative server goal (every 200 eggs hatched in a server pays everyone).
* **Social:** per-player plots, view-only visiting, 3 global OrderedDataStore leaderboards, personal stats, leaderstats.
* **Offline progress:** 1h (+research) at 50% efficiency.

### Adding content
* New creature/mutation/trait/egg/recipe: add a row in `Creatures.lua`. New machine/zone: `Machines.lua`.
  New research: `Research.lua`. New quest/achievement/event: `Quests.lua`. New Echo upgrade: `Prestige.lua`
  (plus one `kind` branch in `Stats.compute` if it needs a new effect type). `tests/test_all.lua` validates cross-references.

## Testing

No Roblox Studio is available in the build environment, so the checks below run on the standalone
[Luau](https://github.com/luau-lang/luau/releases) CLI:

```
LUAU_DIR=/path/to/luau-release API_DUMP=/path/to/API-Dump.json ./tools/check.sh
```
| Check | What it proves |
|---|---|
| `luau-compile` on every file | syntax |
| `tests/test_all.lua` (~390 assertions) | config cross-references; formulas; insufficient/sufficient funds; garbage and NaN inputs; inventory cap; pity; assignment slots/compatibility; fusion validation; research prerequisites + exclusivity; rebirth reset/keep rules + confirmation; quests (no double claim, ordering); achievements; offline cap; save-shape/migration |
| `tests/sim.lua` | greedy-bot pacing (first rebirth available after ~2h of play for an optimised bot) |
| `tests/mock_run.lua` | the **real** server+client scripts executed on a fake Roblox runtime: DataStore retry + session lock + save/restore round-trip, plots, every UI page renders without error, buying/hatching/researching/fusing/claiming/rebirthing by clicking real UI buttons, remote hardening (bad types, unknown actions, rate limiting), multi-player isolation |
| `tools/check_props.py` | property names used in UI helpers exist on the Roblox classes (API dump) |

### What has NOT been verified (needs a human in Studio)
The mocked runtime cannot show real rendering or engine behaviour. Please manually check in Studio:
* UI layout/legibility on phone, tablet and PC (use the Device Emulator). Layout uses a `UIScale` derived from the
  viewport (design space ~1100x650) but was not seen on a real screen.
* Plot visuals (machine models, pets, decor per zone), character placement on spawn, ProximityPrompts.
* Real DataStore / OrderedDataStore / MessagingService behaviour, and Robux flows (need real gamepass/product IDs).
* Multi-server session-lock behaviour and `BindToClose` timing.
* Balance beyond the first rebirth (the simulation only covers the first run).

### Manual configuration
* Put real IDs in `src/shared/Monetization.lua` (gamepasses/products). They are `0` (disabled) by default.
* Enable Studio access to API services (see above).

## Status checklist
Done: factory plot per player, economy, 6 machines, 18 creatures, inventory, assignment + production, mutation + fusion,
upgrade shop, research tree, rebirth + Echo shop, persistence, tutorial + progression UI, leaderboards, server-side validation,
quests/achievements/events framework, visiting, monetization scaffolding (receipts, passes, cosmetic themes).

Not built (designed-for, deliberately out of MVP scope): **Dimensions** and **Advanced Prestige** (research node
`dim3` "Rift Mapping" and the Rift Egg are the first hook), clans/groups, trading, stealing, seasonal reward track,
character cosmetics/emotes (add products to `Monetization.lua` + grant handlers in `PurchaseService`), audio, animations/VFX polish.
