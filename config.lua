Config = {}

Config.Debug = false

Config.RequiredItem = 'diving_gear'
Config.MapItem = 'treasure_map'
Config.BoatRentalTokenItem = 'dive_boat_token'
Config.AnchorItem = 'boat_anchor'

Config.OxygenDurationAt100 = 900 -- 100% durability = 900 seconds oxygen
Config.MinimumDurabilityToUse = 5
Config.DurabilityDrainPerMinute = 7
Config.SearchDuration = 7000
Config.SearchRespawnTime = 1200 -- seconds
Config.EnableDrownDamage = true
Config.DrownTick = 5000
Config.DrownHealthRemove = 10

Config.UseIlleniumAppearance = true
Config.UseFallbackComponents = true

Config.TargetIcon = 'fas fa-water'
Config.TargetLabel = 'Search Dive Spot'


Config.UI = {
    accent = '#61dafb',
    warning = '#ffb84d',
    danger = '#ff5f6d',
    lowOxygenThreshold = 60,
    criticalOxygenThreshold = 30
}

Config.Sonar = {
    enabled = true,
    updateMs = 2500,
    maxRange = 250.0,
    closeMarkerDistance = 35.0,
    closeNotifyDistance = 25.0,
    blipSprite = 161,
    blipColour = 3,
    blipScale = 0.75,
    label = 'Dive Signal',
    marker = {
        type = 1,
        scale = vec3(1.25, 1.25, 1.25),
        colour = { r = 0, g = 180, b = 255, a = 120 },
        bobUpAndDown = false,
        faceCamera = false
    }
}


Config.Rental = {
    enabled = true,
    ped = 'a_m_y_jetski_01',
    coords = vec4(2818.32, -619.23, 2.62, 271.94),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    price = 500,
    durationMinutes = 60,
    label = 'Dive Gear Rental'
}

Config.BoatRental = {
    enabled = true,
    ped = 'a_m_m_bevhills_02',
    coords = vec4(-1604.58, 5257.74, 2.08, 28.65),
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    price = 500,
    durationMinutes = 60,
    label = 'Boat Rental',
    spawn = vec4(-1617.32, 5250.33, 0.18, 25.0),
    model = 'dinghy',
}

Config.Dispatch = {
    enabled = true,
    resource = 'cd_dispatch',
    chance = 45,
    jobs = { 'police' },
    title = 'Illegal Dive Activity',
    message = 'Suspicious underwater crate activity has been reported near %s.',
    blip = {
        sprite = 68,
        scale = 1.0,
        colour = 1,
        flashes = true,
        text = 'Illegal Dive Activity',
        time = 5,
        radius = 0
    }
}



Config.GearProps = {
    enabled = true, -- set true if you want an attached tank prop as extra visible gear
    tank = {
        enabled = true,
        model = 'p_s_scuba_tank_s',
        bone = 24818,
        pos = vec3(-0.28, -0.22, 0.0),
        rot = vec3(0.0, 90.0, 180.0)
    }
}

Config.FallbackAppearance = {
   male = {
    components = {
        { component = 1, drawable = 175, texture = 0 }, -- mask
        { component = 3, drawable = 11, texture = 0 },  -- ✅ FIXED ARMS
        { component = 4, drawable = 94, texture = 0 },  -- legs
        { component = 6, drawable = 67, texture = 0 },  -- fins
        { component = 7, drawable = 0, texture = 0 },   -- chain
        { component = 8, drawable = 15, texture = 0 },  -- undershirt
        { component = 9, drawable = 0, texture = 0 },   -- vest
        { component = 10, drawable = 0, texture = 0 },  -- decals
        { component = 11, drawable = 243, texture = 0 } -- torso
    }
},

    female = {
        components = {
            { component = 1, drawable = 28, texture = 0 },
            { component = 3, drawable = 15, texture = 0 },
            { component = 4, drawable = 97, texture = 0 },
            { component = 6, drawable = 70, texture = 0 },
            { component = 8, drawable = 15, texture = 0 },
            { component = 10, drawable = 0, texture = 0 },
            { component = 11, drawable = 251, texture = 0 },
            { component = 9, drawable = 0, texture = 0 }
        }
    }
}

Config.Props = {
    normal = {
        'prop_tool_box_04',
        'prop_barrel_exp_01a',
        'prop_crate_11e',
        'xm_prop_x17_bag_01a'
    },
    chest = {
        'prop_box_wood05a'
    },
    illegal = {
        'prop_mp_drug_package',
        'prop_cs_cardbox_01',
        'prop_boxpile_07d'
    }
}

Config.SkillChecks = {
    normal = { 'easy', 'easy' },
    chest = { 'easy', 'medium', 'medium' },
    illegal = { 'medium', 'medium', 'hard' }
}

Config.LootTables = {
    basic = {
        { item = 'rusty_can', chance = 12, min = 1, max = 3 },
        { item = 'broken_phone', chance = 8, min = 1, max = 1 },
        { item = 'sea_glass', chance = 12, min = 1, max = 4 },
        { item = 'fishing_hook', chance = 10, min = 1, max = 3 },
        { item = 'scrap_metal', chance = 14, min = 1, max = 3 },
        { item = 'old_watch', chance = 8, min = 1, max = 1 },
        { item = 'shell_necklace', chance = 8, min = 1, max = 2 },
        { item = 'silver_ring', chance = 7, min = 1, max = 2 },
        { item = 'waterlogged_wallet', chance = 7, min = 1, max = 1 },
        { item = 'ship_log', chance = 4, min = 1, max = 1 },
        { item = 'pearl', chance = 5, min = 1, max = 2 },
        { item = 'gold_coin', chance = 5, min = 1, max = 2 }
    },

    chest = {
        { item = 'gold_coin', chance = 18, min = 1, max = 4 },
        { item = 'pearl', chance = 14, min = 1, max = 3 },
        { item = 'diamond_ring', chance = 10, min = 1, max = 2 },
        { item = 'silver_ring', chance = 10, min = 1, max = 2 },
        { item = 'old_watch', chance = 9, min = 1, max = 2 },
        { item = 'cracked_tablet', chance = 8, min = 1, max = 1 },
        { item = 'lost_briefcase', chance = 7, min = 1, max = 1 },
        { item = 'diver_helmet', chance = 5, min = 1, max = 1 },
        { item = 'ancient_relic', chance = 4, min = 1, max = 1 },
        { item = 'treasure_map_piece', chance = 10, min = 1, max = 2 },
        { item = 'goldchain', chance = 5, min = 1, max = 3 }
    },

    illegal = {
        { item = 'drug_package', chance = 22, min = 1, max = 3 },
        { item = 'weapon_crate_part', chance = 18, min = 1, max = 2 },
        { item = 'cokebaggy', chance = 12, min = 1, max = 4 },
        { item = 'weed_brick', chance = 10, min = 1, max = 2 },
        { item = 'advancedlockpick', chance = 8, min = 1, max = 1 },
        { item = 'lockpick', chance = 8, min = 1, max = 2 },
        { item = 'pistol_ammo', chance = 8, min = 1, max = 2 },
        { item = 'cracked_tablet', chance = 5, min = 1, max = 1 },
        { item = 'lost_briefcase', chance = 4, min = 1, max = 1 },
        { item = 'diamond_ring', chance = 5, min = 1, max = 1 }
    },

    treasure_map_reward = {
        { item = 'ancient_relic', chance = 15, min = 1, max = 1 },
        { item = 'diver_helmet', chance = 10, min = 1, max = 1 },
        { item = 'gold_coin', chance = 18, min = 2, max = 6 },
        { item = 'pearl', chance = 14, min = 2, max = 5 },
        { item = 'diamond_ring', chance = 10, min = 1, max = 3 },
        { item = 'goldchain', chance = 10, min = 2, max = 5 },
        { item = 'lost_briefcase', chance = 8, min = 1, max = 1 },
        { item = 'cracked_tablet', chance = 5, min = 1, max = 1 },
        { item = 'treasure_map_piece', chance = 10, min = 1, max = 3 }
    }
}

Config.DiveZones = {
    {
        name = 'Pacific Reef',
        coords = vec3(-1814.24, -1222.11, 0.0),
        radius = 85.0,
        minDepth = 8.0,
        maxDepth = 30.0,
        searchSpots = 12,
        rareChests = 2,
        illegalCrates = 1,
        lootTable = 'basic',
        chestTable = 'chest',
        illegalTable = 'illegal',
        blip = {
            enabled = true,
            sprite = 597,
            colour = 3,
            scale = 0.8,
            label = 'Dive Zone'
        }
    },
    {
        name = 'Sunken Wreck',
        coords = vec3(3172.55, -377.24, 0.0),
        radius = 95.0,
        minDepth = 15.0,
        maxDepth = 40.0,
        searchSpots = 10,
        rareChests = 2,
        illegalCrates = 1,
        lootTable = 'basic',
        chestTable = 'chest',
        illegalTable = 'illegal',
        blip = {
            enabled = true,
            sprite = 597,
            colour = 5,
            scale = 0.8,
            label = 'Wreck Dive'
        }
    }
}

Config.TreasureMaps = {
    {
        id = 'map_wreck_1',
        label = 'Wreck Treasure Map',
        zoneName = 'Sunken Wreck',
        coords = vec3(3151.34, -408.58, -30.0),
        radius = 4.0,
        table = 'treasure_map_reward',
        prop = 'prop_ld_case_01',
        blip = {
            enabled = false,
            sprite = 587,
            colour = 46,
            scale = 0.7,
            label = 'Treasure Search Area'
        }
    }
}
