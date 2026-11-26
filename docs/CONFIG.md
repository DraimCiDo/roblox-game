# What to edit where

Change the value, keep the key. Keys of items, perks and drop effects are stored in player saves.
After editing, run `scripts/check.ps1` and `lune run tests/snapshot.luau --update`, then review the
diff of `tests/snapshot.txt`: it lists exactly what changed in prices, odds and texts of content.

| What | File |
| --- | --- |
| Item prices, drop weights, items per container, delivery time, opening steps | `src/server/Config/Loot.luau` |
| Quality chances and price multiplier, order price share, daily reward, safe mini-game | `src/server/Config/Balance.luau` |
| Distances, action rate limit, gallery interval, mopping job | `src/server/Config/Rules.luau` |
| Start coins, mop reward and its streak bonus, minimum order price, daily reward delay | `src/shared/Config/GameConfig.luau` |
| Container names, laboratory levels, container odds | `src/shared/Config/Containers.luau` |
| Item names, sizes, colors | `src/shared/Config/Items.luau` |
| Collections | `src/shared/Config/Collections.luau` |
| Perk tree: prices, unlock thresholds, effect strength, names and descriptions | `src/shared/Config/Perks.luau` |
| Drop effects and their prices | `src/shared/Config/DropEffects.luau` |
| Quality condition names and colors | `src/shared/Config/Conditions.luau` |
| Sounds | `src/shared/Config/Sounds.luau` |
| Interface colors, fonts, corners, outlines | `src/shared/Config/UiTheme.luau` |
| Fonts and colors of world signs | `src/shared/Config/Theme.luau` |
| Interface texts | `src/shared/Config/Texts/UI.luau` |
| Server notifications and kick reasons | `src/shared/Config/Texts/Notices.luau` |
| Tutorial hints | `src/shared/Config/Texts/Tutorial.luau` |
| Signs, boards and prompts in the world | `src/shared/Config/Texts/World.luau` |
| Why a perk is locked | `src/shared/Config/Texts/Rules.luau` |

Words in braces in texts, such as `{coins}`, are filled in by code: keep them.

Quality chances in `Balance.luau` must add up to 100.
