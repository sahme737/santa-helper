# Launch checklist

## 1. Publish the place

1. `rojo build -o SantasLittleHelper.rbxl`, open it in Studio.
2. File → Publish to Roblox → create a new experience "Santa's Little Helper".
3. Game Settings → Security → turn on **Enable Studio Access to API Services**
   (to test saving in Studio).
4. Game Settings → Avatar: R15 recommended (sweaters and hats are sized for it,
   R6 works too).
5. Playtest with 2-3 players (Test → Clients and Servers) to check plots,
   pet gifting, present drops and the server goal.

## 2. Create the Robux items

Creator Dashboard → your experience → Monetization.

- **Passes:** Double Cheer, Elf Auto-Loader, Lucky Hooves, Extra Stable Stall,
  North Pole VIP.
- **Developer Products:** Handful/Snowdrift/Blizzard of Snowflakes, Hot Cocoa
  Boost, Northern Lights Reindeer.

Copy each id into `src/shared/Config.luau` (`GAME_PASSES` / `DEV_PRODUCTS`,
the `id` field). Items with `id = 0` show "Coming soon", so you can launch
before setting them up. Suggested prices are in the `robux` field.

## 3. Audio

Add licensed music from the Creator Store to `Config.SOUNDS.Music` (and
optionally better click/coin sounds). Leave `""` to keep it silent.

## 4. Store page

- Icon + 3-5 thumbnails: the plaza tree at sunset, a busy workshop, the sleigh
  over town, a golden reindeer hatch.
- Description keywords: Christmas, tycoon, pets, reindeer, sleigh, presents.
- Age guidelines questionnaire (no violence, no chat changes).
- Enable private servers (cheap) and turn on Social Links.

## 5. Admins and QA

Add your UserId to `Config.ADMINS` to use the QA commands in live servers.
Remove it before going big, or keep it if you want live moderation tools.

## 6. After Dec 31

`Config.EVENT.END_TIME` controls the event banner, present drops and the
Advent calendar. Push a new end date or re-theme for New Year's.
