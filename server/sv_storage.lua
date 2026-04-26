-- nex_elevators | server/sv_storage.lua
-- JSON persistence layer.
-- On first run (file absent / empty) seeds data/elevators.json from Config.Elevators.
-- Exposes: Storage_Load, Storage_GetAll, Storage_Create, Storage_Update, Storage_Delete

local DATA_FILE  = 'data/elevators.json'
local _elevators = {}

-- ─── Internal helpers ────────────────────────────────────────────────────────

local function ReadFile()
    local content = LoadResourceFile(GetCurrentResourceName(), DATA_FILE)
    if not content or content == '' then return nil end
    local ok, decoded = pcall(json.decode, content)
    if ok and type(decoded) == 'table' then return decoded end
    print('^1[nex_elevators] Failed to decode ' .. DATA_FILE .. '^0')
    return nil
end

local function WriteFile(data)
    local ok, encoded = pcall(json.encode, data, { indent = true })
    if not ok then
        print('^1[nex_elevators] json.encode error: ' .. tostring(encoded) .. '^0')
        return false
    end
    local saved = SaveResourceFile(GetCurrentResourceName(), DATA_FILE, encoded, -1)
    if not saved then
        print('^1[nex_elevators] SaveResourceFile failed for ' .. DATA_FILE .. '^0')
        return false
    end
    return true
end

local function SeedFromConfig()
    if type(Config.Elevators) ~= 'table' or #Config.Elevators == 0 then return end
    WriteFile(Config.Elevators)
    print(string.format('^2[nex_elevators] Seeded %d elevator(s) from Config.Elevators^0',
        #Config.Elevators))
end

-- ─── Public API ──────────────────────────────────────────────────────────────

--- Loads elevators into memory. Seeds from Config on first run.
function Storage_Load()
    local data = ReadFile()
    if not data or #data == 0 then
        SeedFromConfig()
        data = ReadFile() or {}
    end
    _elevators = data
    print(string.format('^2[nex_elevators] Loaded %d elevator(s)^0', #_elevators))
end

--- Returns the in-memory elevator table (by reference).
--- @return table
function Storage_GetAll()
    return _elevators
end

--- Appends a new elevator and persists.
--- @param  elevatorData  table
--- @return boolean       success
function Storage_Create(elevatorData)
    _elevators[#_elevators + 1] = elevatorData
    return WriteFile(_elevators)
end

--- Replaces the elevator at a 1-based index and persists.
--- @param  index         number
--- @param  elevatorData  table
--- @return boolean       success
function Storage_Update(index, elevatorData)
    if not _elevators[index] then return false end
    _elevators[index] = elevatorData
    return WriteFile(_elevators)
end

--- Removes the elevator at a 1-based index and persists.
--- @param  index  number
--- @return boolean  success
function Storage_Delete(index)
    if not _elevators[index] then return false end
    table.remove(_elevators, index)
    return WriteFile(_elevators)
end