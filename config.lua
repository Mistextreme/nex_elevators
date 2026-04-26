Config = {}

---@type 'qbox'|'esx'|'qbcore'|'ox'
Config.Framework = "qbox"

-- Debug mode: enables zone debug drawing
Config.Debug = false

-- Interaction key (default: E = 38)
Config.InteractKey = 38

-- Zone size for each elevator floor trigger
Config.ZoneSize = vector3(2.0, 2.0, 4.0)

-- Screen fade duration (ms) for teleport transition
Config.FadeDuration = 800

-- Whether to freeze the player during teleportation
Config.FreezeOnTransit = true

-- Elevator sound effects (set to nil to disable)
-- Uses native PlaySoundFrontend
Config.Sound = {
    enter  = { name = "Elevator_Open",          ref = "DLC_DMOD_Prop_Editor_Sounds" },
    move   = { name = "FLIGHT_DETAILS_TICKER",  ref = "DLC_HEIST_PLANNING_BOARD_SOUNDS" },
    arrive = { name = "Elevator_Close",         ref = "DLC_DMOD_Prop_Editor_Sounds" },
}

--[[
    DEFAULT ELEVATORS
    These are only used on FIRST RUN if data/elevators.json doesn't exist yet.
    After that, all elevator data is managed in-game via /elevatoradmin.
    You can safely clear this table after the first import.
]]

Config.Elevators = {
    {
        name = "Los Santos Tower",
        jobRequired = nil,
        floors = {
            {
                label = "Ground Floor",
                coords = vector3(-1091.595, -808.896, 19.268),
                heading = 220.0,
            },
            {
                label = "Rooftop",
                coords = vector3(-1085.711, -816.883, 34.333),
                heading = 219.162,
            },
        },
    },
    {
        name = "Maze Bank",
        jobRequired = { name = "police", minGrade = 0 },
        floors = {
            {
                label = "Lobby",
                coords = vector3(-75.22, -818.12, 31.54),
                heading = 0.0,
            },
            {
                label = "Offices",
                coords = vector3(-75.22, -818.12, 41.54),
                heading = 0.0,
            },
            {
                label = "Executive Suite",
                coords = vector3(-75.22, -818.12, 51.54),
                heading = 0.0,
                jobRequired = { name = "police", minGrade = 3 },
            },
        },
    },
}
