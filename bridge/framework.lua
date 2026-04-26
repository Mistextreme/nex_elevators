-- nex_elevators | bridge/framework.lua
-- Client-side framework bridge: job queries and notifications.
-- Loaded before cl_main.lua; exposes Bridge_GetJob() and Bridge_Notify().

local _ESX    = nil
local _QBCore = nil

if Config.Framework == 'esx' then
    _ESX = exports['es_extended']:getSharedObject()

elseif Config.Framework == 'qbcore' then
    _QBCore = exports['qb-core']:GetCoreObject()

elseif Config.Framework == 'qbox' then
    _QBCore = exports['qbx_core']:GetCoreObject()
end

--- Returns the local player's job name and grade level.
--- @return string  jobName
--- @return number  jobGrade
function Bridge_GetJob()
    if Config.Framework == 'esx' and _ESX then
        local data = _ESX.GetPlayerData()
        if data and data.job then
            return data.job.name, data.job.grade or 0
        end

    elseif (Config.Framework == 'qbcore' or Config.Framework == 'qbox') and _QBCore then
        local data = _QBCore.Functions.GetPlayerData()
        if data and data.job then
            local grade = data.job.grade
            return data.job.name, (type(grade) == 'table' and grade.level or grade) or 0
        end

    elseif Config.Framework == 'ox' then
        local ok, groups = pcall(exports.ox_core.GetPlayerGroups, exports.ox_core)
        if ok and groups then
            for name, grade in pairs(groups) do
                return name, grade
            end
        end
    end

    return 'unemployed', 0
end

--- Sends a notification to the local player.
--- @param message    string
--- @param msgType    string|nil  'success' | 'error' | 'inform'
function Bridge_Notify(message, msgType)
    msgType = msgType or 'inform'

    if Config.Framework == 'esx' and _ESX then
        _ESX.ShowNotification(message)

    elseif (Config.Framework == 'qbcore' or Config.Framework == 'qbox') and _QBCore then
        local qbType = (msgType == 'error') and 'error' or
                       (msgType == 'success') and 'success' or 'primary'
        _QBCore.Functions.Notify(message, qbType)

    else
        -- ox_lib is always available via shared_scripts
        lib.notify({
            title       = 'Elevator',
            description = message,
            type        = msgType,
        })
    end
end