--[[
    nx_shared / shared/bridge.lua
    Cross-resource access to nx_core.

    FiveM resources do not share a Lua state, so a consumer cannot call
    `NX.GetSetting` defined inside nx_core. Everything that crosses a resource
    boundary must go through an export. This file wraps those exports in one
    place so consumers never repeat the pcall/feature-detection boilerplate.

    All helpers degrade to safe defaults when nx_core is not running.
]]

NX = NX or {}
NX.Core = NX.Core or {}

local CORE = 'nx_core'

local EMPTY_STATE = {
    money = { cash = 0, bank = 0, crypto = 0 },
    job = { name = 'unemployed', label = 'Civilian', onduty = false, grade = { level = 0, name = '' } },
    metadata = {},
    permissions = {},
    settings = {},
}

local function coreAvailable()
    return GetResourceState(CORE) == 'started'
end

--- Call a nx_core export defensively.
--- NOTE: `exports['nx_core']:Fn(a)` resolves to `Fn(a)` — the export proxy does
--- not forward `self`. Passing the exports table here would shift every
--- argument by one and silently break every call (this was a real bug: the HUD
--- never hid and settings never applied).
local function call(name, ...)
    if not coreAvailable() then return nil end
    local target = exports[CORE]
    local fn = target[name]
    if type(fn) ~= 'function' then return nil end
    local ok, result = pcall(fn, ...)
    if not ok then
        NX.Log.warn('nx_shared', ('nx_core export %s failed'):format(name), tostring(result))
        return nil
    end
    return result
end

--- Authoritative player state snapshot (client mirror).
function NX.Core.GetState()
    local state = call('GetState')
    if type(state) == 'table' then return state end
    return EMPTY_STATE
end

--- Read a dotted settings key with a default.
function NX.Core.GetSetting(key, default)
    local state = NX.Core.GetState()
    local node = state.settings
    if type(node) ~= 'table' then return default end
    for part in tostring(key):gmatch('[^%.]+') do
        if type(node) ~= 'table' then return default end
        node = node[part]
    end
    if node == nil then return default end
    return node
end

--- Persist a partial settings change (debounced inside nx_core).
function NX.Core.SaveSettings(partial)
    if type(partial) ~= 'table' then return end
    call('SaveSettings', partial)
end

--- Ask nx_core for a fresh authoritative snapshot.
function NX.Core.RequestState()
    call('RequestState')
end

-- ── Focus manager ───────────────────────────────────────────────────────────

function NX.Core.IsFocused()
    return call('IsFocused') == true
end

function NX.Core.RequestFocus(id)
    return call('RequestFocus', id) == true
end

function NX.Core.ReleaseFocus(id)
    return call('ReleaseFocus', id) == true
end

function NX.Core.TouchFocus()
    call('TouchFocus')
end

-- ── Notifications ───────────────────────────────────────────────────────────

function NX.Core.Notify(payload)
    call('Notify', payload)
end

--- Bootstrap payload (brand, features, locale strings).
function NX.Core.GetBootstrap(cb)
    if not coreAvailable() then return cb({}) end
    local ok = pcall(function()
        exports[CORE]:GetBootstrap(cb)
    end)
    if not ok then cb({}) end
end
