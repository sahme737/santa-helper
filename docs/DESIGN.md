# Santa's Little Helper: Game Design

## Pitch

You're one of Santa's helpers with your own toy workshop. Machines pump out
toys onto a conveyor, the wrapping station turns them into presents, and the
presents pile up in your sack. Load the sleigh to turn presents into **Cheer**
(the main currency), then grow the workshop, hatch reindeer, and fly the sleigh
over town on Christmas Eve.

Audience: kids and adults. Short, readable goals; lots of bright feedback;
nothing scary; social moments in the hub.

## Core loop (seconds to minutes)

1. Machines produce toys automatically (server-side income per second).
2. Toys fill your **sack** (capacity limited).
3. Step on **LOAD SLEIGH** to cash the sack into Cheer.
4. Spend Cheer on the next machine, machine levels, elves, decorations, bigger sack.

**Santa's Sleigh Rush:** Santa's sleigh departs every 5 minutes for the whole
server. Loading in the last 45 seconds pays **x2**. This gives the hub a shared
heartbeat and a reason to keep the sack topped up.

## Mid loop (minutes to an hour)

- **8 toy machines** (Teddy → Train → Rocking Horse → Doll House → Robot →
  Game Console → Rocket → Magic Snow Globe), each upgradable to Lv.25.
- **Elves** (up to 10): +10% production each, visibly hammer at machines.
- **Decorations** (8): +5% each, transform the plot (candy cane fence,
  snowman, lights, tree, gingerbread house, ice sculpture, ornament, star arch).
- **Sleigh Delivery** (the finale): fly over a snowy town of ~65 houses and
  drop presents down glowing chimneys before the night ends. Combos for quick
  drops, a snowflake every 4 presents, a perfect-night bonus. Upgrades:
  Reindeer Speed, Present Magnet, Night Length. Rewards scale with workshop
  income so it's always worth doing.
- **Pet reindeer**: 4 eggs (3 Cheer, 1 Snowflake), 6 rarities from Common to
  Mythic, equip 3 (more with seasons), **evolve 3 identical into a Golden**
  (x2.5), release for snowflakes, **gift** to friends in the server.

## Long loop (days)

- **New Season (prestige):** with all 8 machines and enough Cheer, restart the
  workshop for a permanent +50% Cheer per season, 100 snowflakes, and extra
  reindeer stalls at seasons 1 and 3.
- **Daily streak:** 7-day reward cycle (Cheer, snowflakes, Hot Cocoa boost,
  free egg). Missing a day resets the streak.
- **Advent calendar (Dec 1-25):** one door per day. Doors 7, 14 and 21 give
  exclusive cosmetics; door 25 gives a free **Legendary Starlight** reindeer.
- **Playtime gifts:** 6 gifts at 3 to 60 minutes per session.
- **Offline earnings:** elves keep working at 25% for up to 8 hours.
- **Global leaderboards:** Top Present Deliverers and Merriest Workshops.
- **Limited-time event:** the event banner counts down to Dec 31.

## Social

- 6 workshops around one plaza; visit other players' plots.
- **Present Drops:** every 6 minutes a giant glowing present lands in the
  plaza; everyone who reaches it gets a gift.
- **Server goal:** every 150 presents delivered by anyone rewards the whole
  server with snowflakes (co-op).
- Big hatches and new seasons are announced to the server.
- Ugly sweater, hat and trail cosmetics are visible to everyone.

## Currencies

| Currency | Earned by | Spent on |
| --- | --- | --- |
| ⭐ Cheer | Loading the sleigh, deliveries, drops, daily gifts | Machines, upgrades, elves, decor, sleigh, Cheer eggs, coin cosmetics, New Season |
| ❄ Snowflakes | Deliveries, daily/advent/playtime gifts, server goals, drops, releasing pets, seasons (or Robux) | Snowflake egg, premium cosmetics |

## Fair monetization

The whole game is playable and completable for free. Robux buys
**accelerators and extraordinary extras**, never the only path to power:

| Item | Type | Why it's fair |
| --- | --- | --- |
| Double Cheer (249) | Pass | Classic accelerator |
| Elf Auto-Loader (149) | Pass | Convenience: sack loads itself |
| Lucky Hooves (199) | Pass | Better odds; every pet is still hatchable free |
| Extra Stable Stall (149) | Pass | +1 slot; free players gain 2 slots from seasons |
| North Pole VIP (299) | Pass | Golden Crown cosmetic, name tag, +25% earned snowflakes |
| Snowflake packs (49 / 229 / 549) | Product | Snowflakes are also earned many ways |
| Hot Cocoa Boost (39) | Product | Same boost the daily gifts give for free |
| Northern Lights Reindeer (399) | Product | Exclusive look, +400%: strong but weaker than the free-to-hatch Mythic (+500%) |

No paid random items: the Robux reindeer is a direct purchase, and every egg
shows its exact odds in the menu.

## Tuning

Every number lives in `src/shared/Config.luau`. Formulas are in
`src/shared/Economy.luau` (pure functions shared by client and server).
Rough pacing (simulated): second machine in under a minute, all 8 machines in
~40 min, first New Season in about an hour. Sleigh deliveries and drops speed
this up a little.

## Ideas for after launch

- Gift trading with two-sided confirmation.
- Co-op sleigh runs (two players, one sleigh).
- More towns for delivery (Gingerbread Village, Ice Castle).
- Snowball fights in the plaza.
- New Year's event re-skin after Dec 31.
