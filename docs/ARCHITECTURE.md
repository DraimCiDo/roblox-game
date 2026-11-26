# Architecture

## Layers

```
Client (Controllers, UI)  --Remotes-->  Server (Services -> Gameplay)  -->  DataStore
          ^                                        |
          +---------------- DataChanged -----------+
              Shared: Catalog, Config, Network, Types, Util, Models, Loader
```

The server decides everything. The client sends intents and shows what the server sent.
Everything under `src/shared` replicates to the client: no secrets there.

## Layout

```
src/server/
  Services/    loaded by Loader: SimulatorService (composition root), PlayerDataService
  Gameplay/    one module per action area: Orders, Opening, Loot, Inventory, Perks, Settings,
               Rewards, Rankings, Plots, View, State, Tutorial, Mop
  Economy/     prices and random rolls
  World/       binds the Studio scene: World, Sector/, Boards, Delivery, Items, Hall, ItemAssets
  Visuals/     Containers/ (one module per type), DropEffects/ (one module per style)
  Network/     server-to-client sound events
  Config/      Loot, Balance, Rules (server only)
src/client/
  Controllers/ loaded by Loader: DataController, LootController, SimulatorController
  UI/          Style (cartoon kit), Window, Components, Format, Hud, Guide, Icons, Menus, Screens/
  Visuals/     3D previews in the interface
  Audio/       Sfx
src/shared/
  Catalog.luau read API and rules over Config (perk availability, container odds)
  PerkTree.luau which perk nodes are visible and where they stand
  Config/      editable content, see CONFIG.md; Texts/ holds every player-visible string
  Models/      procedural item models
  Network/     Remotes registry
  Types.luau, Loader.luau, Util/
```

## Loading

`Main.server.luau` calls `Remotes.init()` then `Loader.load(Services)`; `Main.client.luau` calls
`Loader.load(Controllers)`. The Loader requires every direct child module, runs `Init()` on all,
then `Start()` on each in its own thread. Modules outside these two folders are plain modules:
they are required by whoever needs them.

## Game loop

`SimulatorService` wires remotes and the world, validates and rate-limits actions, hands each one to a
`Gameplay` module inside `PlayerDataService:Update`, and ticks every sector. Shared runtime state of
the six sectors lives in `Gameplay/State`; `View.sync` pushes a change to the world and to the owner.
Orders go `queued -> delivery -> sealed -> open -> clear`. Loot positions are stored relative to the pad.

World code looks parts of the Studio scene up by their (Russian) instance names. Those names are
identifiers, not texts: they must match the scene.

## Network

All remotes are declared in `src/shared/Network/Remotes.luau`. The client sends actions through one
`Action` event (`name, argument, extra`); the server checks types and lengths before dispatch.

## Interface

Look is set in `shared/Config/UiTheme.luau`. Screens render into the one window of `UI/Window`; below 420 px
of height (landscape phones) the window, the dock and the dial switch to a compact layout. Notices carry
their tone from the server (`State.tell` / `State.warn`).

## Player data

`PlayerDataService` is the only owner of saves: retries on load (kick on failure so a save is not
overwritten), periodic and shutdown saves, a session lock through `UpdateAsync`, v1 to v2 migration in
`PlayerData_v1`, and an ordered store for the global ranking. Item, perk and effect keys are stored in
saves: renaming one is a data change.

## Checks

- `scripts/check.ps1` / `check.sh`: StyLua, Selene, Rojo build.
- `lune run tests/requires.luau`: every require resolves and every `Module.member` exists.
- `lune run tests/perktree.luau`: visibility and layout of the perk tree.
- `lune run tests/snapshot.luau`: content, prices, odds, perk rules and seeded loot did not change.
  After an intended balance or content change run it with `--update` and review the diff.
- `lune run scripts/balance.luau`: progression pace.

## Deferred

A network library (when traffic grows) and Open Cloud deploys from CI. Significant decisions go to
`docs/decisions/`.
