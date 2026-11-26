# 🎄 Santa's Little Helper

A cozy Christmas toy-workshop tycoon for Roblox. Build toy machines, hire elves,
load Santa's sleigh before it departs, hatch and evolve pet reindeer, dress up in
ugly sweaters, and fly a sleigh over a snowy town dropping presents down chimneys.

Everything in the world (the snowy hub, the giant tree, six workshops, the
stable, the delivery town) is built from code when the server starts, so the
whole game lives in this repo.

See [docs/DESIGN.md](docs/DESIGN.md) for the game design, economy and
monetization, and [docs/PUBLISHING.md](docs/PUBLISHING.md) for the launch checklist.

## Play it in Studio (5 minutes)

1. Install the toolchain with [Rokit](https://github.com/rojo-rbx/rokit):
   ```sh
   rokit install
   ```
2. Install the **Rojo** plugin in Roblox Studio (Plugins → Manage Plugins, or
   `rojo plugin install`).
3. In this folder run:
   ```sh
   rojo serve
   ```
4. Open a new **Baseplate** in Studio, delete the default `Baseplate` part and
   `SpawnLocation`, click **Rojo → Connect**, then press **Play**.

Or build a place file directly: `rojo build -o SantasLittleHelper.rbxl` and open it.

### Testing saves in Studio

Saving needs DataStores: **Game Settings → Security → Enable Studio Access to
API Services** (the place must be published first). Without it the game runs
with a temporary profile and prints a warning, so you can still play.

### QA shortcuts (Studio only)

In Studio, open the **Command Bar** while playing (client side) and run, e.g.:

```lua
require(game.Players.LocalPlayer.PlayerScripts.Client.Lib.Net).request("Dev", "coins")
```

Commands: `coins`, `snowflakes`, `boost`, `reset` (daily/advent/playtime gifts),
`pass:DoubleCheer` (or any pass key) to simulate a game pass. Live servers only
allow UserIds listed in `Config.ADMINS`.

## Project layout

| Path | Lands in | What lives there |
| --- | --- | --- |
| `src/shared` | ReplicatedStorage.Shared | `Config` (all tunables), `Economy` (pure formulas), models built from parts, plot layout |
| `src/server` | ServerScriptService.Server | Authoritative systems: data, workshop, pets, sleigh delivery, rewards, shop, events, leaderboards, world builder |
| `src/client` | StarterPlayerScripts.Client | HUD, menus, sleigh flight controls, effects. Renders state and requests actions only |

Security model: the client can only call one `Request` RemoteFunction; every
handler is rate limited and validates its arguments, and all currency, prices,
odds and rewards are decided on the server.

## Checks

```sh
stylua src            # format
selene src            # lint (run `selene generate-roblox-std` once)
rojo build -o test.rbxl
```

CI runs the same checks on every pull request.
