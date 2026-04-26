-- nex_elevators | client/cl_main.lua
-- Zones, key handling, NUI callbacks, teleportation, admin grab, sound helpers.

local _elevators    = {}    -- synced elevator list from server
local _zones        = {}    -- active lib.zones handles
local _inZoneData   = nil   -- { elevatorIndex, floorIndex } | nil
local _nuiOpen      = false -- elevator panel is focused
local _adminOpen    = false -- admin panel is focused
local _grabbing     = false -- waiting for player to press E to capture a position
local _lastTeleport = 0     -- GetGameTimer() of last approved teleport
local SOFT_COOL     = 3000  -- client-side cooldown gate (ms)

-- ─── Sound ───────────────────────────────────────────────────────────────────

local function PlayElevatorSound(key)
    local s = Config.Sound and Config.Sound[key]
    if s and s.name and s.ref then
        PlaySoundFrontend(-1, s.name, s.ref, true)
    end
end

-- ─── Zone management ─────────────────────────────────────────────────────────

local function ClearZones()
    for _, zone in ipairs(_zones) do
        zone:remove()
    end
    _zones      = {}
    _inZoneData = nil
    lib.hideTextUI()
end

local function BuildZones()
    ClearZones()

    for eIdx, elevator in ipairs(_elevators) do
        for fIdx, floor in ipairs(elevator.floors) do
            local coords = vector3(floor.coords.x, floor.coords.y, floor.coords.z)

            local zone = lib.zones.box({
                coords   = coords,
                size     = Config.ZoneSize,
                rotation = floor.heading or 0,
                debug    = Config.Debug,

                onEnter = function()
                    _inZoneData = { elevatorIndex = eIdx, floorIndex = fIdx }
                    if not _nuiOpen and not _adminOpen and not _grabbing then
                        lib.showTextUI('[E] Use Elevator', { position = 'left-center' })
                    end
                end,

                onExit = function()
                    if _inZoneData
                    and _inZoneData.elevatorIndex == eIdx
                    and _inZoneData.floorIndex    == fIdx then
                        _inZoneData = nil
                        lib.hideTextUI()
                    end
                end,
            })

            _zones[#_zones + 1] = zone
        end
    end
end

-- ─── Elevator UI ─────────────────────────────────────────────────────────────

--- Builds the floor list and opens the NUI elevator panel.
--- @param elevatorIndex     number  1-based index in _elevators
--- @param currentFloorIndex number  which floor the player is standing on
local function OpenElevatorUI(elevatorIndex, currentFloorIndex)
    local elevator = _elevators[elevatorIndex]
    if not elevator then return end

    -- Client-side elevator-level gate (server re-validates before teleporting)
    if elevator.jobRequired then
        local jobName, jobGrade = Bridge_GetJob()
        if jobName  ~= elevator.jobRequired.name
        or jobGrade <  (elevator.jobRequired.minGrade or 0) then
            Bridge_Notify('You do not have access to this elevator.', 'error')
            return
        end
    end

    local jobName, jobGrade = Bridge_GetJob()
    local floors = {}

    for i, floor in ipairs(elevator.floors) do
        local locked = false
        if floor.jobRequired then
            if jobName  ~= floor.jobRequired.name
            or jobGrade <  (floor.jobRequired.minGrade or 0) then
                locked = true
            end
        end
        floors[#floors + 1] = {
            id      = i,
            label   = floor.label,
            locked  = locked,
            current = (i == currentFloorIndex),
        }
    end

    PlayElevatorSound('enter')
    lib.hideTextUI()

    _nuiOpen = true
    SetNuiFocus(true, true)
    SendNuiMessage(json.encode({
        action = 'openElevator',
        data   = {
            id     = elevatorIndex,
            name   = elevator.name,
            floors = floors,
        },
    }))
end

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

-- Resource ready — request the elevator list from server
RegisterNuiCallback('init', function(_data, cb)
    TriggerServerEvent('nex_elevators:requestElevators')
    cb({})
end)

-- Player closed the elevator panel
RegisterNuiCallback('closeElevator', function(_data, cb)
    _nuiOpen = false
    SetNuiFocus(false, false)
    if _inZoneData then
        lib.showTextUI('[E] Use Elevator', { position = 'left-center' })
    end
    cb({})
end)

-- Player tapped a floor button
RegisterNuiCallback('selectFloor', function(data, cb)
    -- Soft client-side cooldown to prevent spam
    local now = GetGameTimer()
    if (now - _lastTeleport) < SOFT_COOL then
        cb({ ok = false })
        return
    end

    local elevatorIndex = tonumber(data.elevatorId)
    local floorIndex    = tonumber(data.floorId)

    if not elevatorIndex or not floorIndex then
        cb({ ok = false })
        return
    end

    TriggerServerEvent('nex_elevators:selectFloor', elevatorIndex, floorIndex)
    cb({ ok = true })
end)

-- ─── Admin NUI Callbacks ─────────────────────────────────────────────────────

RegisterNuiCallback('closeAdmin', function(_data, cb)
    _adminOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNuiCallback('adminCreateElevator', function(data, cb)
    TriggerServerEvent('nex_elevators:adminCreate', data)
    cb({})
end)

RegisterNuiCallback('adminUpdateElevator', function(data, cb)
    local index   = tonumber(data.id)
    local payload = data.data
    if index and payload then
        TriggerServerEvent('nex_elevators:adminUpdate', index, payload)
    end
    cb({})
end)

RegisterNuiCallback('adminDeleteElevator', function(data, cb)
    local index = tonumber(data.id)
    if index then
        TriggerServerEvent('nex_elevators:adminDelete', index)
    end
    cb({})
end)

-- Admin clicked "Add Position": release NUI so the player can walk around
RegisterNuiCallback('adminStartGrab', function(_data, cb)
    _grabbing  = true
    _adminOpen = false
    SetNuiFocus(false, false)
    Bridge_Notify('Walk to the spot and press [E] to capture the position.', 'inform')
    cb({})
end)

-- ─── Server → Client Events ──────────────────────────────────────────────────

-- Full elevator list sync (on init and after every admin change)
RegisterNetEvent('nex_elevators:syncElevators', function(elevators)
    _elevators = elevators or {}
    BuildZones()

    -- If admin panel is open, push the refreshed list into it
    if _adminOpen then
        SendNuiMessage(json.encode({
            action = 'adminSyncElevators',
            data   = _elevators,
        }))
    end
end)

-- Server approved the floor selection — perform the actual teleport
RegisterNetEvent('nex_elevators:doTeleport', function(coords, heading)
    _lastTeleport = GetGameTimer()
    local ped     = PlayerPedId()

    PlayElevatorSound('move')

    -- Fade out
    DoScreenFadeOut(Config.FadeDuration)
    Wait(Config.FadeDuration)

    if Config.FreezeOnTransit then
        FreezeEntityPosition(ped, true)
    end

    -- Move player; clearArea = false to avoid erasing nearby entities
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, heading)

    -- Allow the world to load before fading back in
    Wait(300)

    if Config.FreezeOnTransit then
        FreezeEntityPosition(ped, false)
    end

    DoScreenFadeIn(Config.FadeDuration)
    PlayElevatorSound('arrive')

    -- Close the elevator panel after arrival
    _nuiOpen = false
    SetNuiFocus(false, false)
    SendNuiMessage(json.encode({ action = 'closeElevator' }))
end)

-- Server rejected the teleport request
RegisterNetEvent('nex_elevators:teleportDenied', function(reason)
    Bridge_Notify(reason or 'Access denied.', 'error')
    -- Do not force-close the UI; let the player dismiss it themselves
end)

-- Server confirmed admin — open the admin panel
RegisterNetEvent('nex_elevators:openAdminPanel', function(elevators)
    _elevators = elevators or {}
    _adminOpen = true
    SetNuiFocus(true, true)
    SendNuiMessage(json.encode({
        action = 'openAdmin',
        data   = _elevators,
    }))
end)

-- Server denied the /elevatoradmin command
RegisterNetEvent('nex_elevators:adminDenied', function()
    Bridge_Notify('You do not have permission to manage elevators.', 'error')
end)

-- Server responded to a create / update / delete action
RegisterNetEvent('nex_elevators:adminResponse', function(result)
    -- Forward result toast to NUI
    SendNuiMessage(json.encode({
        action = 'adminResponse',
        data   = result,
    }))
    -- Push the updated list (already refreshed by syncElevators arriving first)
    SendNuiMessage(json.encode({
        action = 'adminSyncElevators',
        data   = _elevators,
    }))
end)

-- ─── Key Press Loop ──────────────────────────────────────────────────────────

CreateThread(function()
    while true do

        -- Active zone and no UI open → listen for the interact key
        if _inZoneData and not _nuiOpen and not _adminOpen and not _grabbing then
            Wait(0)
            if IsControlJustPressed(0, Config.InteractKey) then
                OpenElevatorUI(_inZoneData.elevatorIndex, _inZoneData.floorIndex)
            end

        -- Grab mode → wait for E press to capture position
        elseif _grabbing then
            Wait(0)
            if IsControlJustPressed(0, Config.InteractKey) then
                _grabbing = false

                local ped     = PlayerPedId()
                local pos     = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)

                -- 1. Send captured coords to NUI (adds floor entry to React state)
                SendNuiMessage(json.encode({
                    action = 'adminCoordsResult',
                    data   = { x = pos.x, y = pos.y, z = pos.z, heading = heading },
                }))

                -- 2. Small delay so the state update settles, then reopen admin panel
                Wait(100)
                _adminOpen = true
                SetNuiFocus(true, true)
                SendNuiMessage(json.encode({
                    action = 'openAdmin',
                    data   = _elevators,
                }))

                Bridge_Notify('Position captured!', 'success')
            end

        else
            -- Nothing active — low-frequency poll to save CPU
            Wait(300)
        end

    end
end)

-- ─── Resource Cleanup ────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    ClearZones()
    lib.hideTextUI()
    SetNuiFocus(false, false)
end)