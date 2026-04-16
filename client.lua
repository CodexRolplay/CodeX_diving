local diveZones = {}
local searchedSpots = {}
local rentalData = {}
local boatRentalData = {}

local currentGear = {
    equipped = false,
    slot = nil,
    oxygen = 0,
    durability = 0
}



local spawnedEntities = {}
local targetRefs = {}
local spotEntityRefs = {}
local savedAppearance = nil
local savedComponents = {}
local rentalBoat = nil
local rentalBoatExpire = nil
local treasureState = nil
local treasureTargetRef = nil
local treasureEntity = nil
local gearObjects = {}
local remoteScubaProps = {}
local activeRemoteDivers = {}
local uiVisible = false
local lastHudPayload = nil
local hintBlip = nil
local lastHintNotifyAt = 0
local isBoatAnchored = false
local anchoredBoat = nil

local function getUnixTime()
    local t = GetCloudTimeAsInt()
    if t and t > 0 then
        return t
    end

    return 0
end

local function notify(desc, kind)
    lib.notify({
        title = 'Diving',
        description = desc,
        type = kind or 'inform'
    })
end

local function deepCopy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deepCopy(v)
    end
    return out
end

local function isFreemodeMale(ped)
    return GetEntityModel(ped) == joaat('mp_m_freemode_01')
end

local function getFallbackSet(ped)
    return isFreemodeMale(ped) and Config.FallbackAppearance.male or Config.FallbackAppearance.female
end

local function restoreFallbackComponents()
    local ped = PlayerPedId()

    for componentId, old in pairs(savedComponents) do
        SetPedComponentVariation(ped, componentId, old.drawable, old.texture, 0)
    end

    savedComponents = {}
end

local function applyFallbackAppearance()
    if not Config.UseFallbackComponents then return false end

    local ped = PlayerPedId()
    local set = getFallbackSet(ped)
    if not set or not set.components then return false end

    savedComponents = {}

    for _, part in ipairs(set.components) do
        savedComponents[part.component] = {
            drawable = GetPedDrawableVariation(ped, part.component),
            texture = GetPedTextureVariation(ped, part.component)
        }

        SetPedComponentVariation(ped, part.component, part.drawable, part.texture, 0)
    end

    return true
end

local function tryIlleniumApply(enable)
    if not Config.UseIlleniumAppearance then return false end
    if GetResourceState('illenium-appearance') ~= 'started' then return false end

    local ped = PlayerPedId()
    local okGet, appearance = pcall(function()
        return exports['illenium-appearance']:getPedAppearance(ped)
    end)

    if not okGet or not appearance then
        return false
    end

    if enable then
        savedAppearance = deepCopy(appearance)
        local modified = deepCopy(appearance)
        modified.components = modified.components or {}

        local fallback = getFallbackSet(ped)
        if not fallback or not fallback.components then
            return false
        end

        local replace = {}
        for _, part in ipairs(fallback.components) do
            replace[part.component] = part
        end

        for _, comp in ipairs(modified.components) do
            local r = replace[comp.component_id]
            if r then
                comp.drawable = r.drawable
                comp.texture = r.texture
            end
        end

        local okSet = pcall(function()
            exports['illenium-appearance']:setPedAppearance(ped, modified)
        end)

        return okSet
    else
        if not savedAppearance then return false end
        local restoreAppearance = deepCopy(savedAppearance)
        local okSet = pcall(function()
            exports['illenium-appearance']:setPedAppearance(ped, restoreAppearance)
        end)
        if okSet then
            savedAppearance = nil
        end
        return okSet
    end
end

local function clearGearObjects()
    for _, obj in pairs(gearObjects) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    gearObjects = {}
end

local function removeRemoteScubaProp(serverId)
    local obj = remoteScubaProps[serverId]
    if obj and DoesEntityExist(obj) then
        DeleteEntity(obj)
    end
    remoteScubaProps[serverId] = nil
end

local function attachLocalGearObject(model, bone, pos, rot)
    local ped = PlayerPedId()
    local hash = joaat(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end

    local obj = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAsMissionEntity(obj, true, true)
    AttachEntityToEntity(
        obj,
        ped,
        GetPedBoneIndex(ped, bone),
        pos.x, pos.y, pos.z,
        rot.x, rot.y, rot.z,
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(hash)
    gearObjects[#gearObjects + 1] = obj
end

local function attachRemoteScubaProp(serverId)
    if not activeRemoteDivers[serverId] then
        removeRemoteScubaProp(serverId)
        return
    end

    local localServerId = GetPlayerServerId(PlayerId())
    if serverId == localServerId then
        return
    end

    if not Config.GearProps or not Config.GearProps.enabled then return end
    if not Config.GearProps.tank or not Config.GearProps.tank.enabled then return end

    local player = GetPlayerFromServerId(serverId)
    if player == -1 then
        removeRemoteScubaProp(serverId)
        return
    end

    local ped = GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) then
        removeRemoteScubaProp(serverId)
        return
    end

    removeRemoteScubaProp(serverId)

    local tank = Config.GearProps.tank
    local hash = joaat(tank.model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end

    local obj = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAsMissionEntity(obj, true, true)
    AttachEntityToEntity(
        obj,
        ped,
        GetPedBoneIndex(ped, tank.bone),
        tank.pos.x, tank.pos.y, tank.pos.z,
        tank.rot.x, tank.rot.y, tank.rot.z,
        true, true, false, true, 1, true
    )

    remoteScubaProps[serverId] = obj
    SetModelAsNoLongerNeeded(hash)
end

local function applyGearProps()
    if not Config.GearProps or not Config.GearProps.enabled then return end
    clearGearObjects()

    if Config.GearProps.tank and Config.GearProps.tank.enabled then
        attachLocalGearObject(
            Config.GearProps.tank.model,
            Config.GearProps.tank.bone,
            Config.GearProps.tank.pos,
            Config.GearProps.tank.rot
        )
    end
end

local function applyGearAppearance()
    local applied = tryIlleniumApply(true)
    if not applied then
        applyFallbackAppearance()
    end
    applyGearProps()
end

local function removeGearAppearance()
    local removed = tryIlleniumApply(false)
    if not removed then
        local ped = PlayerPedId()
        restoreFallbackComponents(ped, getFallbackSet(ped))
    end
    clearGearObjects()
end

local function setHudVisible(visible)
    if uiVisible == visible then return end
    uiVisible = visible
    SendNUIMessage({ action = 'visible', visible = visible })
    if not visible then
        lastHudPayload = nil
    end
end

local function updateHud(force)
    if not currentGear.equipped then
        setHudVisible(false)
        return
    end

    local status = 'STABLE'
    if currentGear.oxygen <= 30 or currentGear.durability <= 20 then
        status = 'CRITICAL'
    elseif currentGear.oxygen <= 60 or currentGear.durability <= 50 then
        status = 'LOW'
    end

    local payload = {
        action = 'update',
        visible = true,
        oxygen = currentGear.oxygen,
        oxygenPct = math.max(0, math.min(100, math.floor((currentGear.oxygen / math.max(1, Config.OxygenDurationAt100)) * 100))),
        tank = currentGear.durability,
        status = status
    }

    if force or payload.oxygen ~= (lastHudPayload and lastHudPayload.oxygen)
        or payload.tank ~= (lastHudPayload and lastHudPayload.tank)
        or payload.status ~= (lastHudPayload and lastHudPayload.status)
        or not uiVisible then
        setHudVisible(true)
        SendNUIMessage(payload)
        lastHudPayload = payload
    end
end

local function cleanupTargetsAndProps()
    for _, ref in pairs(targetRefs) do
        pcall(function()
            exports.ox_target:removeLocalEntity(ref.entity, ref.optionName)
        end)
    end
    targetRefs = {}

    for _, ent in pairs(spawnedEntities) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    spawnedEntities = {}
    spotEntityRefs = {}
end

local function spotKey(zoneIndex, spotType, spotIndex)
    return ('%s:%s:%s'):format(zoneIndex, spotType, spotIndex)
end

local function removeSpotEntity(zoneIndex, spotType, spotIndex)
    local key = spotKey(zoneIndex, spotType, spotIndex)
    local ref = spotEntityRefs[key]
    if not ref then return end

    pcall(function()
        exports.ox_target:removeLocalEntity(ref.entity, ref.optionName)
    end)

    if DoesEntityExist(ref.entity) then
        DeleteEntity(ref.entity)
    end

    spotEntityRefs[key] = nil
end

local function isSpotOnCooldown(zoneIndex, spotType, spotIndex)
    local key = spotKey(zoneIndex, spotType, spotIndex)
    local expiresAt = searchedSpots[key]

    if not expiresAt then
        return false
    end

    local now = getUnixTime()
    if now <= 0 then
        return false
    end

    return expiresAt > now
end

local function getWaterDepthHere(coords)
    local found, waterZ = GetWaterHeight(coords.x, coords.y, coords.z + 5.0)
    if not found then return 0 end
    return math.abs(coords.z - waterZ)
end

local function inValidDepth(zone, coords)
    local depth = getWaterDepthHere(coords)
    return depth >= zone.minDepth and depth <= zone.maxDepth
end

local function canSearch(zoneIndex, spotType, spotIndex)
    if not currentGear.equipped or currentGear.oxygen <= 0 then return false end
    if isSpotOnCooldown(zoneIndex, spotType, spotIndex) then return false end
    local ped = PlayerPedId()
    if not IsPedSwimmingUnderWater(ped) then return false end
    local zone = Config.DiveZones[zoneIndex]
    if not zone then return false end
    return inValidDepth(zone, GetEntityCoords(ped))
end

local function dispatchIllegal(zoneIndex)
    if not Config.Dispatch.enabled then return end
    if GetResourceState(Config.Dispatch.resource) ~= 'started' then return end
    if math.random(1, 100) > Config.Dispatch.chance then return end

    local zone = Config.DiveZones[zoneIndex]
    if not zone then return end

    local ok, data = pcall(function()
        return exports['cd_dispatch']:GetPlayerInfo()
    end)

    if not ok or not data then return end

    TriggerServerEvent('cd_dispatch:AddNotification', {
        job_table = Config.Dispatch.jobs,
        coords = data.coords,
        title = Config.Dispatch.title,
        message = Config.Dispatch.message:format(zone.name),
        flash = 0,
        unique_id = data.unique_id,
        sound = 1,
        blip = Config.Dispatch.blip
    })
end

local function spawnProp(model, coords, heading)
    local hash = joaat(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(obj, heading or math.random(0, 359) + 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    SetModelAsNoLongerNeeded(hash)
    spawnedEntities[#spawnedEntities + 1] = obj
    return obj
end

local function playSearch(spotType)
    local checks = Config.SkillChecks[spotType] or { 'easy' }
    if not lib.skillCheck(checks, { 'w', 'a', 's', 'd' }) then
        notify('You fumbled the search.', 'error')
        return false
    end

    local ped = PlayerPedId()
    if not IsPedSwimmingUnderWater(ped) then
        notify('You need to stay underwater while searching.', 'error')
        return false
    end

    if spotType == 'chest' then
        notify('Rare chest opened.', 'success')
    elseif spotType == 'illegal' then
        notify('Suspicious crate opened.', 'success')
    else
        notify('Search successful.', 'success')
    end

    return true
end

local function handleSearch(zoneIndex, spotType, spotIndex)
    if not canSearch(zoneIndex, spotType, spotIndex) then
        notify('You cannot search this right now.', 'error')
        return
    end

    if not playSearch(spotType) then return end

    if spotType == 'illegal' then
        dispatchIllegal(zoneIndex)
    end

    TriggerServerEvent('codex_diving:server:searchSpot', {
        zoneIndex = zoneIndex,
        spotType = spotType,
        spotIndex = spotIndex,
        gearSlot = currentGear.slot
    })
end

local function registerEntityTarget(entity, zoneIndex, spotType, spotIndex)
    local optionName = ('codex_diving_%s_%s_%s'):format(zoneIndex, spotType, spotIndex)

    exports.ox_target:addLocalEntity(entity, {
        {
            name = optionName,
            icon = Config.TargetIcon,
            label = spotType == 'normal' and 'Search Debris'
                or (spotType == 'chest' and 'Open Rare Chest' or 'Open Illegal Crate'),
            canInteract = function()
                return canSearch(zoneIndex, spotType, spotIndex)
            end,
            onSelect = function()
                handleSearch(zoneIndex, spotType, spotIndex)
            end
        }
    })

    targetRefs[#targetRefs + 1] = { entity = entity, optionName = optionName }
    spotEntityRefs[spotKey(zoneIndex, spotType, spotIndex)] = { entity = entity, optionName = optionName }
end

local function createZoneProps()
    cleanupTargetsAndProps()

    for zoneIndex, zoneData in pairs(diveZones) do
        for spotIndex, coords in pairs(zoneData.normal or {}) do
            local model = Config.Props.normal[math.random(1, #Config.Props.normal)]
            registerEntityTarget(spawnProp(model, coords, math.random(0, 359)), zoneIndex, 'normal', spotIndex)
        end

        for spotIndex, coords in pairs(zoneData.chest or {}) do
            local model = Config.Props.chest[math.random(1, #Config.Props.chest)]
            registerEntityTarget(spawnProp(model, coords, math.random(0, 359)), zoneIndex, 'chest', spotIndex)
        end

        for spotIndex, coords in pairs(zoneData.illegal or {}) do
            local model = Config.Props.illegal[math.random(1, #Config.Props.illegal)]
            registerEntityTarget(spawnProp(model, coords, math.random(0, 359)), zoneIndex, 'illegal', spotIndex)
        end
    end
end

local function createBlips()
    for _, zone in ipairs(Config.DiveZones) do
        if zone.blip and zone.blip.enabled then
            local radiusBlip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
            SetBlipColour(radiusBlip, zone.blip.colour or 3)
            SetBlipAlpha(radiusBlip, 90)

            local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(blip, zone.blip.sprite or 597)
            SetBlipColour(blip, zone.blip.colour or 3)
            SetBlipScale(blip, zone.blip.scale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(zone.blip.label or zone.name)
            EndTextCommandSetBlipName(blip)
        end
    end
end

local function removeHintBlip()
    if hintBlip and DoesBlipExist(hintBlip) then
        RemoveBlip(hintBlip)
    end
    hintBlip = nil
end

local function updateHintBlip(coords)
    if not coords then
        removeHintBlip()
        return
    end

    if not hintBlip or not DoesBlipExist(hintBlip) then
        hintBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(hintBlip, Config.Sonar.blipSprite or 161)
        SetBlipColour(hintBlip, Config.Sonar.blipColour or 3)
        SetBlipScale(hintBlip, Config.Sonar.blipScale or 0.75)
        SetBlipAsShortRange(hintBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.Sonar.label or 'Dive Signal')
        EndTextCommandSetBlipName(hintBlip)
    else
        SetBlipCoords(hintBlip, coords.x, coords.y, coords.z)
    end
end

local function giveBoatKeys(vehicle)
    if not DoesEntityExist(vehicle) then return end

    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleNeedsToBeHotwired(vehicle, false)

    local plate = GetVehicleNumberPlateText(vehicle)

    if GetResourceState('qbx_vehiclekeys') == 'started' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
        return
    end

    if GetResourceState('qb-vehiclekeys') == 'started' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
        return
    end

    if GetResourceState('wasabi_carlock') == 'started' then
        TriggerServerEvent('wasabi_carlock:giveKey', plate)
        return
    end
end

local function clearBoatAnchor(forceVehicle)
    local vehicle = forceVehicle or anchoredBoat
    if vehicle and DoesEntityExist(vehicle) then
        FreezeEntityPosition(vehicle, false)
        SetBoatAnchor(vehicle, false)
    end
    anchoredBoat = nil
    isBoatAnchored = false
end

local function toggleBoatAnchor()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or not DoesEntityExist(vehicle) or not IsThisModelABoat(GetEntityModel(vehicle)) then
        notify('You need to be in a boat to use the anchor.', 'error')
        return
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        notify('You need to be the driver to use the anchor.', 'error')
        return
    end

    if isBoatAnchored and anchoredBoat and anchoredBoat ~= vehicle then
        clearBoatAnchor()
    end

    if isBoatAnchored and anchoredBoat == vehicle then
        clearBoatAnchor(vehicle)
        notify('Anchor lifted.', 'inform')
        return
    end

    SetBoatAnchor(vehicle, true)
    FreezeEntityPosition(vehicle, true)
    SetVehicleEngineOn(vehicle, false, true, true)
    anchoredBoat = vehicle
    isBoatAnchored = true
    notify('Anchor dropped.', 'success')
end

local function returnRentalBoat()
    if not rentalBoat or not DoesEntityExist(rentalBoat) then
        notify('No rental boat to return.', 'error')
        return
    end

    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local bCoords = GetEntityCoords(rentalBoat)

    if #(pCoords - bCoords) > 12.0 then
        notify('You need to be near the rental boat.', 'error')
        return
    end

    if anchoredBoat == rentalBoat then
        clearBoatAnchor(rentalBoat)
    end

    TriggerServerEvent('codex_diving:server:returnBoat')

    DeleteEntity(rentalBoat)
    rentalBoat = nil
    rentalBoatExpire = nil

    notify('Rental boat returned.', 'success')
end

local function getNearestDiveSpot()
    local pCoords = GetEntityCoords(PlayerPedId())
    local nearestDist, nearestSpot = nil, nil

    for zoneIndex, zoneData in pairs(diveZones) do
        for spotType, spots in pairs(zoneData) do
            for spotIndex, coords in pairs(spots) do
                if not isSpotOnCooldown(zoneIndex, spotType, spotIndex) then
                    local dist = #(pCoords - coords)
                    if not nearestDist or dist < nearestDist then
                        nearestDist = dist
                        nearestSpot = coords
                    end
                end
            end
        end
    end

    return nearestSpot, nearestDist
end

local function createPed(modelName, coords, scenario)
    local hash = joaat(modelName)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end

    local ped = CreatePed(0, hash, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(hash)
    return ped
end

local function createRentalPed()
    if not Config.Rental.enabled then return end
    local ped = createPed(Config.Rental.ped, Config.Rental.coords, Config.Rental.scenario)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'codex_diving_rental',
            icon = 'fas fa-person-swimming',
            label = Config.Rental.label,
            onSelect = function()
                lib.registerContext({
                    id = 'codex_diving_rental_menu',
                    title = 'Dive Gear Rental',
                    options = {
                        {
                            title = ('Rent Gear - £%s'):format(Config.Rental.price),
                            description = ('Rental lasts %s minutes'):format(Config.Rental.durationMinutes),
                            onSelect = function()
                                TriggerServerEvent('codex_diving:server:rentGear')
                            end
                        }
                    }
                })
                lib.showContext('codex_diving_rental_menu')
            end
        }
    })
end

local function createBoatRentalPed()
    if not Config.BoatRental.enabled then return end
    local ped = createPed(Config.BoatRental.ped, Config.BoatRental.coords, Config.BoatRental.scenario)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'codex_diving_boat_rental',
            icon = 'fas fa-ship',
            label = Config.BoatRental.label,
            onSelect = function()
                lib.registerContext({
                    id = 'codex_diving_boat_rental_menu',
                    title = 'Boat Rental',
                    options = {
                        {
                            title = ('Rent Boat - £%s'):format(Config.BoatRental.price),
                            description = ('Rental lasts %s minutes'):format(Config.BoatRental.durationMinutes),
                            onSelect = function()
                                TriggerServerEvent('codex_diving:server:rentBoat')
                            end
                        }
                    }
                })
                lib.showContext('codex_diving_boat_rental_menu')
            end
        }
    })
end

local function updateScubaState(enable)
    local ped = PlayerPedId()
    SetEnableScuba(ped, enable)
    SetPedMaxTimeUnderwater(ped, enable and 2000.0 or 10.0)
end

local function resetGearState()
    currentGear.equipped = false
    currentGear.slot = nil
    currentGear.oxygen = 0
    currentGear.durability = 0
    updateHud()
end

local function equipGear(slot)
    local ped = PlayerPedId()

    if currentGear.equipped then
        notify('Diving gear is already equipped.', 'error')
        return
    end

    if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then
        notify('You cannot put diving gear on while swimming.', 'error')
        return
    end

    local finished = lib.progressCircle({
        duration = 4000,
        position = 'bottom',
        label = 'Putting on diving gear',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = 'clothingshirt',
            clip = 'try_shirt_positive_d'
        }
    })

    if not finished then
        notify('You stopped putting on the diving gear.', 'error')
        return
    end

    local ok, data = lib.callback.await('codex_diving:server:prepareGearUse', false, slot)
    if not ok then
        notify(data or 'Could not equip gear.', 'error')
        return
    end

    currentGear.equipped = true
    currentGear.slot = data.slot
    currentGear.durability = data.durability
    currentGear.oxygen = data.oxygen

    applyGearAppearance()
    updateScubaState(true)
    TriggerServerEvent('codex_diving:server:setScubaVisible', true)
    updateHud(true)
    notify(('Diving gear equipped. Oxygen: %ss'):format(currentGear.oxygen), 'success')
end

local function unequipGear(silent)
    if not currentGear.equipped then
        if not silent then
            notify('You are not wearing diving gear.', 'error')
        end
        return
    end

    local ped = PlayerPedId()
    local underwater = IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)

    local finished
    if underwater then
        finished = lib.progressCircle({
            duration = 3000,
            position = 'bottom',
            label = 'Removing diving gear',
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true
            }
        })
    else
        finished = lib.progressCircle({
            duration = 3500,
            position = 'bottom',
            label = 'Taking off diving gear',
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true
            },
            anim = {
                dict = 'clothingshirt',
                clip = 'try_shirt_negative_d'
            }
        })
    end

    if not finished then
        if not silent then
            notify('You stopped removing the diving gear.', 'error')
        end
        return
    end

    updateScubaState(false)
    removeGearAppearance()
    resetGearState()
    TriggerServerEvent('codex_diving:server:setScubaVisible', false)

    if not silent then
        notify('Diving gear removed.', 'inform')
    end
end

local function removeTreasureTarget()
    if treasureTargetRef then
        pcall(function()
            exports.ox_target:removeLocalEntity(treasureTargetRef.entity, treasureTargetRef.optionName)
        end)
    end
    treasureTargetRef = nil

    if treasureEntity and DoesEntityExist(treasureEntity) then
        DeleteEntity(treasureEntity)
    end
    treasureEntity = nil
end

local function openTreasureMap(mapId)
    local ok, map = lib.callback.await('codex_diving:server:getTreasureMapData', false, mapId)
    if not ok or not map then
        notify('This treasure map is invalid.', 'error')
        return
    end

    removeTreasureTarget()
    treasureState = map
    SetNewWaypoint(map.coords.x, map.coords.y)

    lib.registerContext({
        id = 'codex_diving_map_info',
        title = map.label,
        options = {
            {
                title = 'Treasure marked',
                description = ('Waypoint set for %s'):format(map.zoneName)
            }
        }
    })
    lib.showContext('codex_diving_map_info')
end

local function createTreasureTargetIfNeeded()
    if not treasureState then return end
    if treasureEntity and DoesEntityExist(treasureEntity) then return end

    local pCoords = GetEntityCoords(PlayerPedId())
    local tCoords = treasureState.coords
    if #(pCoords - tCoords) > 120.0 then return end

    treasureEntity = spawnProp(treasureState.prop or 'prop_ld_case_01', tCoords, math.random(0, 359))
    local optionName = 'codex_diving_treasure'

    exports.ox_target:addLocalEntity(treasureEntity, {
        {
            name = optionName,
            icon = 'fas fa-gem',
            label = 'Dig Up Treasure',
            canInteract = function()
                return currentGear.equipped and currentGear.oxygen > 0 and IsPedSwimmingUnderWater(PlayerPedId())
            end,
            onSelect = function()
                if not currentGear.equipped then
                    notify('You need diving gear.', 'error')
                    return
                end

                if not lib.skillCheck({ 'medium', 'hard' }, { 'w', 'a', 's', 'd' }) then
                    notify('You messed up the treasure recovery.', 'error')
                    return
                end

                if not IsPedSwimmingUnderWater(PlayerPedId()) then
                    notify('You need to stay underwater while recovering treasure.', 'error')
                    return
                end

                notify('Treasure recovered.', 'success')
                TriggerServerEvent('codex_diving:server:redeemTreasure', treasureState.id, currentGear.slot)
                removeTreasureTarget()
                treasureState = nil
            end
        }
    })

    treasureTargetRef = { entity = treasureEntity, optionName = optionName }
end

RegisterNetEvent('codex_diving:client:setScubaVisible', function(serverId, isVisible)
    if not serverId then return end

    if isVisible then
        activeRemoteDivers[serverId] = true
        attachRemoteScubaProp(serverId)
    else
        activeRemoteDivers[serverId] = nil
        removeRemoteScubaProp(serverId)
    end
end)

RegisterNetEvent('codex_diving:client:syncVisibleDivers', function(activeList)
    activeRemoteDivers = activeList or {}

    local localServerId = GetPlayerServerId(PlayerId())
    for serverId, visible in pairs(activeRemoteDivers) do
        if visible and tonumber(serverId) ~= localServerId then
            attachRemoteScubaProp(tonumber(serverId))
        end
    end
end)

RegisterNetEvent('codex_diving:client:useGear', function(itemData)
    if currentGear.equipped then
        unequipGear()
        return
    end

    equipGear(itemData and itemData.slot or nil)
end)

RegisterNetEvent('codex_diving:client:useTreasureMap', function(itemData)
    local metadata = itemData and itemData.metadata or {}
    if not metadata.mapId then
        notify('This map has no treasure data.', 'error')
        return
    end
    openTreasureMap(metadata.mapId)
end)

RegisterNetEvent('codex_diving:client:useAnchor', function()
    toggleBoatAnchor()
end)

RegisterNetEvent('codex_diving:client:updateSpotState', function(zoneIndex, spotType, spotIndex, expires)
    searchedSpots[spotKey(zoneIndex, spotType, spotIndex)] = expires
    removeSpotEntity(zoneIndex, spotType, spotIndex)
end)

RegisterNetEvent('codex_diving:client:updateLocalDurability', function(newDurability)
    currentGear.durability = newDurability
    if currentGear.equipped then
        currentGear.oxygen = math.floor((newDurability / 100) * Config.OxygenDurationAt100)
        updateHud()
    end

    if newDurability < Config.MinimumDurabilityToUse and currentGear.equipped then
        notify('Your tank is too damaged to continue.', 'error')
        unequipGear(true)
    end
end)

RegisterNetEvent('codex_diving:client:spawnRentalBoat', function(spawn, model, expireAt)
    if rentalBoat and DoesEntityExist(rentalBoat) then
        if anchoredBoat == rentalBoat then
            clearBoatAnchor(rentalBoat)
        end
        DeleteEntity(rentalBoat)
    end

    local hash = joaat(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end

    rentalBoat = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleOnGroundProperly(rentalBoat)
    SetEntityAsMissionEntity(rentalBoat, true, true)
    SetVehicleEngineOn(rentalBoat, true, true, false)
    SetVehicleHasBeenOwnedByPlayer(rentalBoat, true)
    SetVehicleDoorsLockedForAllPlayers(rentalBoat, false)
    SetModelAsNoLongerNeeded(hash)
    rentalBoatExpire = expireAt

    giveBoatKeys(rentalBoat)
    TaskWarpPedIntoVehicle(PlayerPedId(), rentalBoat, -1)

    exports.ox_target:addLocalEntity(rentalBoat, {
        {
            name = 'codex_diving_return_boat',
            icon = 'fas fa-ship',
            label = 'Return Rental Boat',
            canInteract = function(entity, distance)
                return entity == rentalBoat and distance <= 3.0
            end,
            onSelect = function()
                returnRentalBoat()
            end
        }
    })

    notify('Your rental boat has been spawned and keys were assigned.', 'success')
end)

CreateThread(function()
    local zones, searched, rentals, boatRentals = lib.callback.await('codex_diving:server:getInitData', false)
    diveZones = zones or {}
    searchedSpots = searched or {}
    rentalData = rentals or {}
    boatRentalData = boatRentals or {}

    createBlips()
    createZoneProps()
    createRentalPed()
    createBoatRentalPed()
    Wait(1000)
    TriggerServerEvent('codex_diving:server:requestVisibleDivers')
end)

CreateThread(function()
    while true do
        if currentGear.equipped then
            Wait(1000)
            if IsPedSwimmingUnderWater(PlayerPedId()) then
                currentGear.oxygen = math.max(0, currentGear.oxygen - 1)
                if currentGear.oxygen == 60 then
                    notify('60 seconds of oxygen left.', 'inform')
                elseif currentGear.oxygen == 30 then
                    notify('30 seconds of oxygen left.', 'error')
                elseif currentGear.oxygen == 0 then
                    notify('You are out of oxygen!', 'error')
                end
                updateHud()
            end
        else
            Wait(1500)
        end
    end
end)

CreateThread(function()
    while true do
        if currentGear.equipped then
            Wait(60000)

            if currentGear.slot then
                TriggerServerEvent('codex_diving:server:drainDurability', currentGear.slot)
            end
        else
            Wait(2000)
        end
    end
end)

CreateThread(function()
    while true do
        if currentGear.equipped and Config.EnableDrownDamage then
            Wait(Config.DrownTick)
            if currentGear.oxygen <= 0 and IsPedSwimmingUnderWater(PlayerPedId()) then
                local ped = PlayerPedId()
                SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - Config.DrownHealthRemove))
            end
        else
            Wait(2000)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(2000)

        if treasureState then
            createTreasureTargetIfNeeded()
        end

        if rentalBoat and rentalBoatExpire and getUnixTime() > rentalBoatExpire then
            if DoesEntityExist(rentalBoat) then
                if anchoredBoat == rentalBoat then
                    clearBoatAnchor(rentalBoat)
                end
                DeleteEntity(rentalBoat)
            end
            rentalBoat = nil
            rentalBoatExpire = nil
            notify('Your rental boat has expired.', 'inform')
        end
    end
end)

CreateThread(function()
    while true do
        if Config.Sonar and Config.Sonar.enabled and currentGear.equipped then
            Wait(Config.Sonar.updateMs or 2500)

            local spot, dist = getNearestDiveSpot()
            if spot and dist and dist < (Config.Sonar.maxRange or 250.0) then
                updateHintBlip(spot)

                if dist < (Config.Sonar.closeNotifyDistance or 25.0) and (GetGameTimer() - lastHintNotifyAt) > 10000 then
                    lastHintNotifyAt = GetGameTimer()
                    notify('Signal getting stronger. You are close to a dive find.', 'inform')
                end
            else
                removeHintBlip()
            end
        else
            removeHintBlip()
            Wait(1500)
        end
    end
end)

CreateThread(function()
    while true do
        if Config.Sonar and Config.Sonar.enabled and currentGear.equipped then
            local spot, dist = getNearestDiveSpot()
            if spot and dist and dist < (Config.Sonar.closeMarkerDistance or 35.0) then
                local marker = Config.Sonar.marker or {}
                local scale = marker.scale or vec3(1.25, 1.25, 1.25)
                local colour = marker.colour or { r = 0, g = 180, b = 255, a = 120 }
                DrawMarker(
                    marker.type or 1,
                    spot.x, spot.y, spot.z + 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    scale.x, scale.y, scale.z,
                    colour.r, colour.g, colour.b, colour.a,
                    marker.bobUpAndDown or false,
                    marker.faceCamera or false,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )
                Wait(0)
            else
                Wait(500)
            end
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(3000)

        for serverId, visible in pairs(activeRemoteDivers) do
            serverId = tonumber(serverId) or serverId

            if not visible then
                removeRemoteScubaProp(serverId)
            else
                local player = GetPlayerFromServerId(serverId)
                if player == -1 then
                    removeRemoteScubaProp(serverId)
                else
                    local ped = GetPlayerPed(player)
                    if ped == 0 or not DoesEntityExist(ped) then
                        removeRemoteScubaProp(serverId)
                    elseif not remoteScubaProps[serverId] or not DoesEntityExist(remoteScubaProps[serverId]) then
                        attachRemoteScubaProp(serverId)
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupTargetsAndProps()
    removeTreasureTarget()
    clearGearObjects()

    if currentGear.equipped then
        updateScubaState(false)
        removeGearAppearance()
    end

    if rentalBoat and DoesEntityExist(rentalBoat) then
        if anchoredBoat == rentalBoat then
            clearBoatAnchor(rentalBoat)
        end
        DeleteEntity(rentalBoat)
    end
    clearBoatAnchor()

    removeHintBlip()
    TriggerServerEvent('codex_diving:server:setScubaVisible', false)
    for serverId, obj in pairs(remoteScubaProps) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    remoteScubaProps = {}
    activeRemoteDivers = {}
    setHudVisible(false)
end)
