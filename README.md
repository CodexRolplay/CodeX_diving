# codex_diving

Advanced diving script for Qbox + ox_inventory + ox_target + ox_lib.

Includes:
- visible diving gear
- illenium-appearance support with fallback components
- dive gear rental ped
- boat rental ped
- boat anchor item
- searchable dive zones
- rare chests
- illegal crates
- underwater props
- skill checks
- cd_dispatch hook for illegal crates
- tank durability metadata
- treasure map system
- persistent zone cooldowns saved to `data/cooldowns.json`

## install

1. Put `codex_diving` in your resources folder.
2. Add `ensure codex_diving` to your server.cfg after ox_lib, ox_inventory, ox_target, qbx_core.
3. Add the item entries below to your `ox_inventory/data/items.lua`.
4. Restart the server.

## ox_inventory items

```lua
['diving_gear'] = {
    label = 'Diving Gear',
    weight = 5000,
    stack = false,
    close = true,
    description = 'Scuba tank, mask and fins.',
    client = {
        event = 'codex_diving:client:useGear'
    }
},

['treasure_map'] = {
    label = 'Treasure Map',
    weight = 100,
    stack = false,
    close = true,
    description = 'A weathered treasure map.',
    client = {
        event = 'codex_diving:client:useTreasureMap'
    }
},

['dive_boat_token'] = {
    label = 'Boat Rental Token',
    weight = 0,
    stack = false,
    close = true,
    description = 'Proof of a temporary boat rental.'
},

['boat_anchor'] = {
    label = 'Boat Anchor',
    weight = 2500,
    stack = false,
    close = true,
    description = 'Use while driving a boat to drop or lift anchor.',
    client = {
        event = 'codex_diving:client:useAnchor'
    }
},
```

## treasure map example give command

Use your normal admin item give command and include metadata:

```lua
exports.ox_inventory:AddItem(source, 'treasure_map', 1, {
    mapId = 'map_wreck_1'
})
```

## notes

- If your illenium-appearance exports use different names, adjust them in `client.lua`.
- If your cd_dispatch build uses a different event shape, adjust `dispatchIllegal()` in `client.lua`.
- Cash rewards are currently given as the `money` item. Change that in `config.lua` loot tables if your server uses a different cash item.
- Cooldowns persist across restarts through `data/cooldowns.json`.
- Boat rental is client-spawned for the renter only.

## likely edits you will want

- change drawable IDs in `Config.FallbackAppearance`
- add more dive zones in `Config.DiveZones`
- add more treasure maps in `Config.TreasureMaps`
- tune prices and durations in `Config.Rental` and `Config.BoatRental`


## UI
- This build uses a custom NUI scuba HUD instead of ox_lib text UI to stop flashing/flicker.
- No extra setup is needed beyond ensuring the resource folder keeps the included `html` files.


## Boat rental extras

- Renting a boat now also gives the player a `boat_anchor` item automatically if they do not already have one.


## latest fix
- Search and treasure recovery no longer use underwater progressCircle, because that was causing false cancels after passing the minigame.


Update in this build:
- Full fallback scuba outfit config now uses a components array in config.lua.
- Putting on and taking off diving gear now uses ox_lib progress circles.
- Taking off gear above water plays a clothing removal animation.
