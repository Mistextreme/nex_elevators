-- nex_elevators | server/sv_main.lua
-- Commands, net events, server-side validation, rate limiting, admin CRUD.

-- Per-player teleport cooldown: source → last approved timestamp (GetGameTimer ms)
local _cooldowns = {}
local COOLDOWN_MS = 3000

-- ─── Startup ─────────────────────────────────────────────────────────────────

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Storage_Load()
end)

-- ─── Sync helpers ────────────────────────────────────────────────────────────

--- Broadcasts the current elevator list to every connected client.
local function SyncAll()
    TriggerClientEvent('nex_elevators:syncElevators', -1, Storage_GetAll())
end

--- Sends the elevator list to a single client.
--- @param src number
local function SyncOne(src)
    TriggerClientEvent('nex_elevators:syncElevators', src, Storage_GetAll())
end

--- Validates admin and sends a standardised error response if denied.
--- @param  src  number
--- @return boolean
local function AssertAdmin(src)
    if Bridge_IsAdmin(src) then return true end
    TriggerClientEvent('nex_elevators:adminResponse', src, {
        success = false,
        message = 'Permission denied.',
    })
    return false
end

-- ─── /elevatoradmin command ──────────────────────────────────────────────────

RegisterCommand('elevatoradmin', function(src, _args)
    if src == 0 then
        print('[nex_elevators] /elevatoradmin cannot be used from console.')
        return
    end

    if not Bridge_IsAdmin(src) then
        TriggerClientEvent('nex_elevators:adminDenied', src)
        return
    end

    TriggerClientEvent('nex_elevators:openAdminPanel', src, Storage_GetAll())
end, false)

-- ─── Elevator request (NUI init) ─────────────────────────────────────────────

RegisterNetEvent('nex_elevators:requestElevators', function()
    SyncOne(source)
end)

-- ─── Floor selection / teleport ──────────────────────────────────────────────

RegisterNetEvent('nex_elevators:selectFloor', function(elevatorIndex, floorIndex)
    local src = source

    -- Rate-limit
    local now = GetGameTimer()
    if _cooldowns[src] and (now - _cooldowns[src]) < COOLDOWN_MS then
        TriggerClientEvent('nex_elevators:teleportDenied', src,
            'Please wait before using the elevator again.')
        return
    end

    -- Validate elevator exists
    local elevators = Storage_GetAll()
    local elevator  = type(elevatorIndex) == 'number' and elevators[elevatorIndex]
    if not elevator then
        TriggerClientEvent('nex_elevators:teleportDenied', src, 'Elevator not found.')
        return
    end

    -- Validate floor exists
    local floor = type(floorIndex) == 'number' and elevator.floors[floorIndex]
    if not floor then
        TriggerClientEvent('nex_elevators:teleportDenied', src, 'Floor not found.')
        return
    end

    -- Elevator-level job check
    if elevator.jobRequired then
        local jobName, jobGrade = Bridge_GetPlayerJob(src)
        if jobName  ~= elevator.jobRequired.name
        or jobGrade <  (elevator.jobRequired.minGrade or 0) then
            TriggerClientEvent('nex_elevators:teleportDenied', src,
                'You do not have access to this elevator.')
            return
        end
    end

    -- Floor-level job check
    if floor.jobRequired then
        local jobName, jobGrade = Bridge_GetPlayerJob(src)
        if jobName  ~= floor.jobRequired.name
        or jobGrade <  (floor.jobRequired.minGrade or 0) then
            TriggerClientEvent('nex_elevators:teleportDenied', src,
                'You do not have access to this floor.')
            return
        end
    end

    _cooldowns[src] = now
    TriggerClientEvent('nex_elevators:doTeleport', src, floor.coords, floor.heading)
end)

-- ─── Admin: Create ───────────────────────────────────────────────────────────

RegisterNetEvent('nex_elevators:adminCreate', function(data)
    local src = source
    if not AssertAdmin(src) then return end

    if type(data) ~= 'table'
    or type(data.name) ~= 'string'
    or data.name == ''
    or type(data.floors) ~= 'table'
    or #data.floors < 1 then
        TriggerClientEvent('nex_elevators:adminResponse', src, {
            success = false, message = 'Invalid elevator data.',
        })
        return
    end

    local ok = Storage_Create(data)
    if ok then
        SyncAll()
        TriggerClientEvent('nex_elevators:adminResponse', src, {
            success = true, message = 'Elevator created.',
        })
    else
        TriggerClientEvent('nex_elevators:adminResponse', src, {
            success = false, message = 'Failed to save. Check server console.',
        })
    end
end)

-- ─── Admin: Update ───────────────────────────────────────────────────────────

RegisterNetEvent('nex_elevators:adminUpdate', function(index, data)
    local src = source
    if not AssertAdmin(src) then return end

    if type(index) ~= 'number' or type(data) ~= 'table' then
        TriggerClientEvent('nex_elevators:adminResponse', src, {
            success = false, message = 'Invalid parameters.',
        })
        return
    end

    local ok = Storage_Update(index, data)
    if ok then
        SyncAll()
        TriggerClientEvent('nex_elevators:adminResponse', src, {
            success = true, message = 'Elevator updated.',
        })
    else
        TriggerClientEvent('nex_elevators:adminResponse', src, {
            success = false, message = 'Elevator not found or save failed.',
        })
    end
end)

-- ─── Admin: Delete ───────────────────────────────────────────────────────────

RegisterNetEvent('nex_elevators:adminDelete', function(index)
    local src = source
    if not AssertAdmin(src) then return end

    if type(index) ~= 'number' then
        TriggerClientEvent('nex_elevators:adminResponse', src, {
            success = false, message = 'Invalid index.',
        })
        return
    end

    local ok = Storage_Delete(index)
    if ok then
        SyncAll()
        TriggerClientEvent('nex_elevators:adminResponse', src, {
            success = true, message = 'Elevator deleted.',
        })
    else
        TriggerClientEvent('nex_elevators:adminResponse', src, {
            success = false, message = 'Elevator not found or save failed.',
        })
    end
end)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    _cooldowns[source] = nil
end)