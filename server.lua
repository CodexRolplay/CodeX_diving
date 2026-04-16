local resourceName = GetCurrentResourceName()
local cooldownFile = 'data/cooldowns.json'

local spawnedZones = {}
local searchedSpots = {}
local rentalEnd = {}
local boatRentalEnd = {}
local activeTreasure = {}

local function ensureDataFile()
    local raw = LoadResourceFile(resourceName, cooldownFile)
    if raw then return end
    SaveResourceFile(resourceName, cooldownFile, "{}", -1)
end

local function saveCooldowns()
    SaveResourceFile(resourceName, cooldownFile, json.encode(searchedSpots), -1)
end

local function loadCooldowns()
    ensureDataFile()
    local raw = LoadResourceFile(resourceName, cooldownFile)
    if not raw or raw == '' then
        searchedSpots = {}
        return
    end

    local decoded = json.decode(raw)
    searchedSpots = type(decoded) == 'table' and decoded or {}
end

local function randomOffset(radius)
    local angle = math.random() * math.pi * 2
    local dist = math.random() * radius
    return math.cos(angle) * dist, math.sin(angle) * dist
end

local function chooseDepth(minDepth, maxDepth)
    return -math.random(math.floor(minDepth), math.floor(maxDepth))
end

local function buildZone(zoneIndex)
    local zone = Config.DiveZones[zoneIndex]
    if not zone then return end

    spawnedZones[zoneIndex] = {
        normal = {},
        chest = {},
        illegal = {}
    }

    for i = 1, (zone.searchSpots or 0) do
        local ox, oy = randomOffset(zone.radius * 0.55)
        spawnedZones[zoneIndex].normal[i] = vec3(zone.coords.x + ox, zone.coords.y + oy, chooseDepth(zone.minDepth, zone.maxDepth))
    end

    for i = 1, (zone.rareChests or 0) do
        local ox, oy = randomOffset(zone.radius * 0.50)
        spawnedZones[zoneIndex].chest[i] = vec3(zone.coords.x + ox, zone.coords.y + oy, chooseDepth(zone.minDepth, zone.maxDepth))
    end

    for i = 1, (zone.illegalCrates or 0) do
        local ox, oy = randomOffset(zone.radius * 0.45)
        spawnedZones[zoneIndex].illegal[i] = vec3(zone.coords.x + ox, zone.coords.y + oy, chooseDepth(zone.minDepth, zone.maxDepth))
    end
end

local function ensureZones()
    for i = 1, #Config.DiveZones do
        if not spawnedZones[i] then
            buildZone(i)
        end
    end
end

local activeScubaDivers = {}

RegisterNetEvent('codex_diving:server:setScubaVisible', function(isVisible)
    local src = source

    if isVisible then
        activeScubaDivers[src] = true
    else
        activeScubaDivers[src] = nil
    end

    TriggerClientEvent('codex_diving:client:setScubaVisible', -1, src, isVisible and true or false)
end)

RegisterNetEvent('codex_diving:server:returnBoat', function()
    local src = source

    -- add refund logic here if you want later
    -- example:
    exports.ox_inventory:AddItem(src, 'money', 250)
end)

RegisterNetEvent('codex_diving:server:requestVisibleDivers', function()
    local src = source
    TriggerClientEvent('codex_diving:client:syncVisibleDivers', src, activeScubaDivers)
end)

AddEventHandler('playerDropped', function()
    local src = source

    if activeScubaDivers[src] then
        activeScubaDivers[src] = nil
        TriggerClientEvent('codex_diving:client:setScubaVisible', -1, src, false)
    end
end)

local function getSpotKey(zoneIndex, spotType, spotIndex)
    return ('%s:%s:%s'):format(zoneIndex, spotType, spotIndex)
end

local function isSpotLocked(zoneIndex, spotType, spotIndex)
    local key = getSpotKey(zoneIndex, spotType, spotIndex)
    return searchedSpots[key] and searchedSpots[key] > os.time()
end

local function lockSpot(zoneIndex, spotType, spotIndex)
    local key = getSpotKey(zoneIndex, spotType, spotIndex)
    searchedSpots[key] = os.time() + Config.SearchRespawnTime
    saveCooldowns()
    return searchedSpots[key]
end

local function pickFromTable(tbl)
    local roll = math.random(1, 100)
    local total = 0
    for _, entry in ipairs(tbl) do
        total = total + entry.chance
        if roll <= total then
            return entry
        end
    end
    return nil
end

local function giveReward(src, reward)
    if not reward then return false, 'Nothing found.' end
    local amount = math.random(reward.min, reward.max)
    local ok = exports.ox_inventory:AddItem(src, reward.item, amount)
    if ok then
        return true, ('You found %sx %s'):format(amount, reward.item)
    end
    return false, 'Inventory full.'
end

local function findGearSlot(src)
    local slots = exports.ox_inventory:Search(src, 'slots', Config.RequiredItem)
    if type(slots) ~= 'table' then return nil end

    for _, item in pairs(slots) do
        if item and item.slot then
            return item.slot
        end
    end

    return nil
end

local function validateGear(src, slot)
    slot = slot or findGearSlot(src)
    if not slot then return false, nil, nil end

    local item = exports.ox_inventory:GetSlot(src, slot)
    if not item or item.name ~= Config.RequiredItem then
        return false, nil, nil
    end

    local durability = item.metadata and item.metadata.durability or 100
    if durability < Config.MinimumDurabilityToUse then
        return false, item, slot
    end

    local rentalExpire = item.metadata and item.metadata.rentalExpire
    if rentalExpire and os.time() > rentalExpire then
        return false, item, slot
    end

    return true, item, slot
end

local function buildTreasureMapData(mapId)
    for _, map in ipairs(Config.TreasureMaps) do
        if map.id == mapId then
            return map
        end
    end
end

lib.callback.register('codex_diving:server:getInitData', function()
    ensureZones()
    return spawnedZones, searchedSpots, rentalEnd, boatRentalEnd
end)

lib.callback.register('codex_diving:server:prepareGearUse', function(src, slot)
    local ok, item, resolvedSlot = validateGear(src, slot)
    if not ok then
        return false, 'Your diving gear is damaged, expired, or missing.'
    end

    local durability = item.metadata and item.metadata.durability or 100
    local oxygen = math.floor((durability / 100) * Config.OxygenDurationAt100)
    return true, {
        slot = resolvedSlot,
        durability = durability,
        oxygen = oxygen
    }
end)

lib.callback.register('codex_diving:server:getTreasureMapData', function(src, mapId)
    local map = buildTreasureMapData(mapId)
    if not map then return false end

    activeTreasure[src] = {
        id = map.id,
        coords = map.coords,
        radius = map.radius,
        table = map.table,
        prop = map.prop
    }

    return true, map
end)

RegisterNetEvent('codex_diving:server:drainDurability', function(slot)
    local src = source
    local ok, item, resolvedSlot = validateGear(src, slot)
    if not ok then return end

    local current = item.metadata and item.metadata.durability or 100
    local newDurability = math.max(0, current - Config.DurabilityDrainPerMinute)
    local oldMeta = item.metadata or {}

    exports.ox_inventory:SetMetadata(src, resolvedSlot, {
        durability = newDurability,
        rented = oldMeta.rented or false,
        rentalExpire = oldMeta.rentalExpire or nil
    })

    TriggerClientEvent('codex_diving:client:updateLocalDurability', src, newDurability)
end)

RegisterNetEvent('codex_diving:server:rentGear', function()
    local src = source
    if not Config.Rental.enabled then return end

    local removed = exports.ox_inventory:RemoveItem(src, 'money', Config.Rental.price)
    if not removed then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Diving',
            description = 'You do not have enough cash.',
            type = 'error'
        })
        return
    end

    rentalEnd[src] = os.time() + ((Config.Rental.durationMinutes or 45) * 60)
    exports.ox_inventory:AddItem(src, Config.RequiredItem, 1, {
        durability = 100,
        rented = true,
        rentalExpire = rentalEnd[src]
    })

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Diving',
        description = ('You rented diving gear for %s minutes.'):format(Config.Rental.durationMinutes),
        type = 'success'
    })
end)

RegisterNetEvent('codex_diving:server:rentBoat', function()
    local src = source
    if not Config.BoatRental.enabled then return end

    local removed = exports.ox_inventory:RemoveItem(src, 'money', Config.BoatRental.price)
    if not removed then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Diving',
            description = 'You do not have enough cash for the boat.',
            type = 'error'
        })
        return
    end

    boatRentalEnd[src] = os.time() + ((Config.BoatRental.durationMinutes or 20) * 60)
    exports.ox_inventory:AddItem(src, Config.BoatRentalTokenItem, 1, {
        expire = boatRentalEnd[src],
        boatModel = Config.BoatRental.model
    })

    local hasAnchor = exports.ox_inventory:Search(src, 'count', Config.AnchorItem)
    if not hasAnchor or hasAnchor < 1 then
        exports.ox_inventory:AddItem(src, Config.AnchorItem, 1, {
            rented = true,
            rentalExpire = boatRentalEnd[src]
        })
    end

    TriggerClientEvent('codex_diving:client:spawnRentalBoat', src, Config.BoatRental.spawn, Config.BoatRental.model, boatRentalEnd[src])
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Boat Rental',
        description = ('Boat rented for %s minutes and an anchor was added to your inventory.'):format(Config.BoatRental.durationMinutes),
        type = 'success'
    })
end)

RegisterNetEvent('codex_diving:server:searchSpot', function(data)
    local src = source
    local zoneIndex = data.zoneIndex
    local spotType = data.spotType
    local spotIndex = data.spotIndex
    local gearSlot = data.gearSlot

    if not zoneIndex or not spotType or not spotIndex then return end
    if not spawnedZones[zoneIndex] or not spawnedZones[zoneIndex][spotType] or not spawnedZones[zoneIndex][spotType][spotIndex] then return end
    if isSpotLocked(zoneIndex, spotType, spotIndex) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Diving',
            description = 'This spot has already been searched.',
            type = 'error'
        })
        return
    end

    local ok = validateGear(src, gearSlot)
    if not ok then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Diving',
            description = 'You need usable diving gear.',
            type = 'error'
        })
        return
    end

    local zone = Config.DiveZones[zoneIndex]
    local tableName = zone.lootTable

    if spotType == 'chest' then
        tableName = zone.chestTable
    elseif spotType == 'illegal' then
        tableName = zone.illegalTable
    end

    local lootTable = Config.LootTables[tableName]
    if not lootTable then return end

    local reward = pickFromTable(lootTable)
    local success, message = giveReward(src, reward)
    local expires = lockSpot(zoneIndex, spotType, spotIndex)

    TriggerClientEvent('codex_diving:client:updateSpotState', -1, zoneIndex, spotType, spotIndex, expires)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Diving',
        description = message,
        type = success and 'success' or 'error'
    })
end)

RegisterNetEvent('codex_diving:server:redeemTreasure', function(mapId, gearSlot)
    local src = source
    local treasure = activeTreasure[src]
    if not treasure or treasure.id ~= mapId then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Treasure',
            description = 'No active treasure map data found.',
            type = 'error'
        })
        return
    end

    local ok = validateGear(src, gearSlot)
    if not ok then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Treasure',
            description = 'You need usable diving gear.',
            type = 'error'
        })
        return
    end

    local tableData = Config.LootTables[treasure.table]
    if not tableData then return end

    local reward = pickFromTable(tableData)
    local success, message = giveReward(src, reward)
    if success then
        exports.ox_inventory:RemoveItem(src, Config.MapItem, 1, { mapId = mapId }, nil, false)
        activeTreasure[src] = nil
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Treasure',
        description = success and ('Treasure found. %s'):format(message) or message,
        type = success and 'success' or 'error'
    })
end)

AddEventHandler('playerDropped', function()
    rentalEnd[source] = nil
    boatRentalEnd[source] = nil
    activeTreasure[source] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= resourceName then return end
    loadCooldowns()
    ensureZones()
end)
