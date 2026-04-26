-- nex_elevators | bridge/sv_framework.lua
-- Server-side framework bridge: admin permission checks and player job queries.
-- Loaded before sv_main.lua; exposes Bridge_IsAdmin() and Bridge_GetPlayerJob().

local _ESX    = nil
local _QBCore = nil

if Config.Framework == 'esx' then
    TriggerEvent('esx:getSharedObject', function(obj)
        _ESX = obj
    end)

elseif Config.Framework == 'qbcore' then
    _QBCore = exports['qb-core']:GetCoreObject()

elseif Config.Framework == 'qbox' then
    _QBCore = exports['qbx_core']:GetCoreObject()
end

--- Returns true when the player has elevator admin privileges.
--- Priority: ACE permission → framework group fallback.
--- @param  src  number  server player id
--- @return boolean
function Bridge_IsAdmin(src)
    -- ACE permission (works regardless of framework, configured in server.cfg)
    if IsPlayerAceAllowed(tostring(src), 'nex_elevators.admin') then
        return true
    end

    if Config.Framework == 'esx' and _ESX then
        local xPlayer = _ESX.GetPlayerFromId(src)
        if xPlayer then
            local group = xPlayer.getGroup()
            return group == 'admin' or group == 'superadmin'
        end

    elseif (Config.Framework == 'qbcore' or Config.Framework == 'qbox') and _QBCore then
        local Player = _QBCore.Functions.GetPlayer(src)
        if Player then
            local perm = Player.PlayerData.permission
            return perm == 'admin' or perm == 'god'
        end

    elseif Config.Framework == 'ox' then
        local ok, groups = pcall(exports.ox_core.GetPlayerGroups, exports.ox_core, src)
        if ok and type(groups) == 'table' then
            return (groups['admin'] or 0) >= 1 or (groups['superadmin'] or 0) >= 1
        end
    end

    return false
end

--- Returns the job name and grade for the given player source.
--- @param  src  number  server player id
--- @return string  jobName
--- @return number  jobGrade
function Bridge_GetPlayerJob(src)
    if Config.Framework == 'esx' and _ESX then
        local xPlayer = _ESX.GetPlayerFromId(src)
        if xPlayer then
            return xPlayer.job.name, xPlayer.job.grade or 0
        end

    elseif (Config.Framework == 'qbcore' or Config.Framework == 'qbox') and _QBCore then
        local Player = _QBCore.Functions.GetPlayer(src)
        if Player then
            local job   = Player.PlayerData.job
            local grade = job.grade
            return job.name, (type(grade) == 'table' and grade.level or grade) or 0
        end

    elseif Config.Framework == 'ox' then
        local ok, groups = pcall(exports.ox_core.GetPlayerGroups, exports.ox_core, src)
        if ok and type(groups) == 'table' then
            for name, grade in pairs(groups) do
                return name, grade
            end
        end
    end

    return 'unemployed', 0
end