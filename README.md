# Auto Layout Switcher

Automatically swaps your Edit Mode layout whenever you activate a different talent loadout. By default, WoW only remembers the last layout used per specialization and swaps when you change specs; this add-on extends that behavior so each talent loadout of the same spec can have its own layout.

## Features

- Map individual loadouts (per specialization) to any Edit Mode layout.
- Defer switches while you are in combat and automatically retry once combat ends.

## Usage

### Options Panel

1. Open `Game Menu > Options > AddOns > Auto Layout Switcher`.
2. Use the **Default layout** dropdown to choose which Edit Mode layout should be used whenever a loadout is set to `Default`. (Pick `Not set` to clear it.)
3. In the per-loadout table, choose one of the following for each loadout:
   - `None (do not switch)` – never change layouts when that loadout activates.
   - `Default layout` – always switch to the layout chosen in step 2.
   - A named layout – switch directly to that layout.
   If you update the currently active loadout, the add-on immediately tries to switch layouts outside combat.

### Slash Commands

- `/als` or `/als open` - Jump straight to the options panel.
- `/als list` - Print all current mappings along with their layout slot/ID.

## Notes

- Layout switching is blocked while you are in combat; a deferred retry runs when combat end.
- If the Default layout is not configured, any loadout set to `Default layout` will behave like `None`.
- If a mapped layout is renamed, the saved entry updates automatically; if it is deleted, `/als list` flags it so you can remap.
