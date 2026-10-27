--[[
    nx_shared / shared/logger.lua
    Unified logging for every NOVARA CITY resource.

    Client: console output only.
    Server: console output + optional persistence to `nx_log`
            + `NX.Log.audit()` for sensitive operations (nx_audit_log).

    Never log credentials, tokens, connection strings or full player
    identifiers. `NX.Log.redact()` is provided for that purpose.
]]

NX = NX or {}
NX.Log = NX.Log or {}

local cfg = (NX.Config and NX.Config.Log) or {}
local LEVELS = { debug = 10, info = 20, warn = 30, error = 40 }
local isServer = IsDuplicityVersion and IsDuplicityVersion()

local currentLevel = LEVELS[cfg.level or 'info'] or 20
local persistLevel = LEVELS[cfg.persistLevel or 'warn'] or 30

local COLORS = {
    debug = '^5',
    info = '^7',
    warn = '^3',
    error = '^1',
}

--[[
    Timestamps
    ----------
    FiveM's client Lua sandbox has no `os` library, so `os.date` cannot be used
    here (this is a shared script). The client falls back to elapsed time since
    the session started, which is what you actually want when reading an F8 log.
]]
local osLib = os -- nil on the client sandbox; reading a missing global is safe
local hasOsDate = type(osLib) == 'table' and type(osLib.date) == 'function'
local bootAt = 0

local function stamp()
    if hasOsDate then
        local ok, value = pcall(osLib.date, '%H:%M:%S')
        if ok and value then return value end
    end
    if bootAt == 0 and type(GetGameTimer) == 'function' then bootAt = GetGameTimer() end
    local elapsed = (type(GetGameTimer) == 'function' and GetGameTimer() or 0) - bootAt
    if elapsed < 0 then elapsed = 0 end
    return ('%02d:%02d'):format(math.floor(elapsed / 60000), math.floor((elapsed % 60000) / 1000))
end

local function truncate(value, limit)
    local text = tostring(value)
    if #text > limit then return text:sub(1, limit) .. '…' end
    return text
end

--- Remove anything that looks like a secret from a string.
function NX.Log.redact(value)
    if type(value) ~= 'string' then return value end
    local out = value
    out = out:gsub('(mysql://)[^%s"\']+', '%1<redacted>')
    out = out:gsub('(password%s*[=:]%s*)[^%s,;"\']+', '%1<redacted>')
    out = out:gsub('(licenseKey%s*[=:]?%s*)[%w_%-]+', '%1<redacted>')
    out = out:gsub('cfxk_[%w_%-]+', '<redacted-key>')
    return out
end

local function serializeDetail(detail)
    if detail == nil then return nil end
    if type(detail) == 'table' then
        local ok, encoded = pcall(json.encode, detail)
        return ok and encoded or tostring(detail)
    end
    return tostring(detail)
end

--- Core emit function.
--- Logging must never raise: a broken log line used to take down the caller
--- (and, on the client, the whole script chunk). Everything is pcall-guarded.
local function emit(level, resource, message, detail)
    local ok, err = pcall(function()
        if not cfg.enabled then return end
        local numeric = LEVELS[level] or 20
        if numeric < currentLevel then return end

        local text = truncate(NX.Log.redact(tostring(message)), cfg.maxMessageLength or 900)
        local line = ('%s[nx:%s] %s %s^7 %s'):format(
            COLORS[level] or '^7',
            tostring(resource),
            stamp(),
            tostring(level):upper(),
            text
        )
        if cfg.echoToConsole ~= false then
            print(line)
        end

        if isServer and cfg.persist and numeric >= persistLevel then
            local payload = serializeDetail(detail)
            -- Fire and forget: logging must never block gameplay.
            MySQL.insert(
                'INSERT INTO `nx_log` (`level`, `resource`, `message`, `detail`) VALUES (?, ?, ?, ?)',
                { level, tostring(resource):sub(1, 64), text, payload },
                function() end
            )
        end
    end)

    if not ok and type(print) == 'function' then
        -- Never recurse into the logger here: just surface the failure plainly.
        print(('[nx:%s] logger failure: %s'):format(tostring(resource), tostring(err)))
    end
end

function NX.Log.debug(resource, message, detail) emit('debug', resource, message, detail) end
function NX.Log.info(resource, message, detail) emit('info', resource, message, detail) end
function NX.Log.warn(resource, message, detail) emit('warn', resource, message, detail) end
function NX.Log.error(resource, message, detail) emit('error', resource, message, detail) end

function NX.Log.setLevel(level)
    if LEVELS[level] then currentLevel = LEVELS[level] end
end

--- Append an entry to the audit trail. Server only.
--- @param category string  e.g. 'economy', 'admin', 'police'
--- @param action string    e.g. 'money.add', 'ban.create'
--- @param data table       { actor = identifier|'system', actorSource = int, target = string, detail = table|string }
function NX.Log.audit(category, action, data)
    if not isServer then return end
    data = data or {}
    local detail = data.detail
    if type(detail) == 'table' then
        local ok, encoded = pcall(json.encode, detail)
        detail = ok and encoded or nil
    end
    MySQL.insert(
        'INSERT INTO `nx_audit_log` (`category`, `action`, `actor`, `actor_source`, `target`, `detail`) VALUES (?, ?, ?, ?, ?, ?)',
        {
            tostring(category):sub(1, 48),
            tostring(action):sub(1, 96),
            tostring(data.actor or 'system'):sub(1, 64),
            tonumber(data.actorSource) or 0,
            data.target and tostring(data.target):sub(1, 64) or nil,
            detail,
        },
        function() end
    )
end
