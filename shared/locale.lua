--[[
    nx_shared / shared/locale.lua
    Minimal, dependency-free localization layer.

    Usage:
        NX.L('notify.saved')
        NX.L('job.contract.accepted', { name = 'Warehouse Run' })
        NX.L('job.contract.accepted', { name = 'Warehouse Run' }, 'en')

    Missing keys fall back to the fallback locale, then to the key itself so a
    missing translation never produces a blank UI element.
]]

NX = NX or {}
NX.Locales = NX.Locales or {}

local currentLocale = (NX.Config and NX.Config.Locale and NX.Config.Locale.default) or 'id'
local fallbackLocale = (NX.Config and NX.Config.Locale and NX.Config.Locale.fallback) or 'en'

--- Register (or extend) a locale table.
function NX.RegisterLocale(code, table_)
    if type(code) ~= 'string' or type(table_) ~= 'table' then return end
    NX.Locales[code] = NX.Locales[code] or {}
    for k, v in pairs(table_) do NX.Locales[code][k] = v end
end

--- Resolve a dotted path inside a locale table.
local function resolve(code, key)
    local node = NX.Locales[code]
    if not node then return nil end
    for part in key:gmatch('[^%.]+') do
        if type(node) ~= 'table' then return nil end
        node = node[part]
    end
    return type(node) == 'string' and node or nil
end

--- Interpolate {placeholders}.
local function interpolate(text, vars)
    if not vars then return text end
    return (text:gsub('{(%w+)}', function(name)
        local value = vars[name]
        if value == nil then return '{' .. name .. '}' end
        return tostring(value)
    end))
end

--- Translate a key.
function NX.L(key, vars, locale)
    if type(key) ~= 'string' then return '' end
    local code = locale or currentLocale
    local text = resolve(code, key) or resolve(fallbackLocale, key) or resolve('en', key)
    if not text then
        if NX.Config and NX.Config.Log and NX.Config.Log.level == 'debug' then
            print(('[nx_shared] missing locale key: %s (%s)'):format(key, code))
        end
        return key
    end
    return interpolate(text, vars)
end

--- Current active locale for this runtime.
function NX.GetLocale()
    return currentLocale
end

--- Server-side: set the process-wide default locale.
function NX.SetLocale(code)
    if NX.Locales[code] then currentLocale = code end
end

--- Expose a JS-safe locale payload for NUI resources.
function NX.GetLocalePayload()
    return {
        locale = currentLocale,
        fallback = fallbackLocale,
        strings = NX.Locales[currentLocale] or {},
        fallbackStrings = NX.Locales[fallbackLocale] or {},
    }
end

-- Apply the configured locale as soon as config is available.
if NX.Config and NX.Config.Locale then
    currentLocale = NX.Config.Locale.default or currentLocale
    fallbackLocale = NX.Config.Locale.fallback or fallbackLocale
end
