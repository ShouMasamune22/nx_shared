--[[
    nx_shared / shared/utils.lua
    Small, dependency-free helpers shared by every NOVARA CITY resource.
    Everything here must be pure (no natives that differ per side unless guarded).
]]

NX = NX or {}
NX.Utils = NX.Utils or {}

local U = NX.Utils
local floor, abs, min, max = math.floor, math.abs, math.min, math.max
local random, randomseed = math.random, math.randomseed

--[[
    Clock
    -----
    IMPORTANT: FiveM's CLIENT Lua sandbox does not expose the `os` library at
    all (`os` is literally nil). This file is a shared script, so any unguarded
    `os.*` call aborts the whole chunk on the client and leaves NX.Utils empty —
    which then breaks every consumer. All time reads go through this one helper.
]]
local fallbackTicks = 0

-- `os` is nil on the client sandbox; reading a missing global is safe, using it
-- is not. Keep it in a local so the intent is explicit and greppable.
local osLib = os

local function nowMs()
    if type(GetGameTimer) == 'function' then
        local value = GetGameTimer()
        if type(value) == 'number' then return value end
    end
    if type(osLib) == 'table' and type(osLib.time) == 'function' then
        return osLib.time() * 1000
    end
    fallbackTicks = fallbackTicks + 1
    return fallbackTicks
end

U.Now = nowMs

--[[
    Random seeding
    --------------
    Seeding at load time with the game timer alone gives every client that
    joined at a similar moment the same sequence — bad for UUID / transaction
    ids. Seed lazily on first use, mixing in the player's server id when it is
    available.
]]
local seeded = false

local function ensureSeeded()
    if seeded then return end
    seeded = true

    local seed = nowMs()
    if type(GetPlayerServerId) == 'function' and type(PlayerId) == 'function' then
        local ok, id = pcall(function() return GetPlayerServerId(PlayerId()) end)
        if ok and type(id) == 'number' then seed = seed + id * 7919 end
    end
    if type(osLib) == 'table' and type(osLib.time) == 'function' then
        seed = seed + osLib.time() * 1000
    end
    pcall(randomseed, seed % 2147483647)
end
U.EnsureSeeded = ensureSeeded

--- Clamp a number into a range.
--- @param value number
--- @param lo number
--- @param hi number
--- @return number
function U.Clamp(value, lo, hi)
    if type(value) ~= 'number' then return lo end
    if value ~= value then return lo end -- NaN guard
    return min(max(value, lo), hi)
end

--- Round to `decimals` places.
function U.Round(value, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return floor(value * mult + 0.5) / mult
end

--- True when the value is a whole number (and not NaN/inf).
function U.IsInt(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge and value % 1 == 0
end

--- Safe integer parse. Returns nil when the input is not a finite integer.
function U.ToInt(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return floor(n + 0.5)
end

--- Truncate + strip control characters from a user supplied string.
function U.SanitizeString(value, maxLen)
    if type(value) ~= 'string' then return '' end
    local clean = value:gsub('%c', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and #clean > maxLen then clean = clean:sub(1, maxLen) end
    return clean
end

--- Deep copy (tables only, functions/threads are referenced).
function U.DeepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do out[U.DeepCopy(k, seen)] = U.DeepCopy(v, seen) end
    return out
end

--- Merge `src` into `dst` recursively without mutating either input.
function U.DeepMerge(dst, src)
    local out = U.DeepCopy(dst or {})
    for k, v in pairs(src or {}) do
        if type(v) == 'table' and type(out[k]) == 'table' then
            out[k] = U.DeepMerge(out[k], v)
        else
            out[k] = U.DeepCopy(v)
        end
    end
    return out
end

--- RFC4122-ish v4 identifier. Not cryptographic, but collision-safe for
--- transaction ids, session ids and audit records.
function U.UUID()
    ensureSeeded()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (template:gsub('[xy]', function(c)
        local v = (c == 'x') and random(0, 15) or (random(0, 3) + 8)
        return string.format('%x', v)
    end))
end

--- Short uppercase reference code, e.g. NX-7F3A9C.
function U.RefCode(prefix)
    ensureSeeded()
    return ('%s-%06X'):format(prefix or 'NX', random(0, 0xFFFFFF))
end

--- Monotonic-ish millisecond timestamp (safe on client and server).
function U.NowMs()
    return nowMs()
end

--- Format a number as currency using the configured symbol.
function U.Money(amount)
    local n = tonumber(amount) or 0
    local symbol = (NX.Config and NX.Config.Economy and NX.Config.Economy.currency) or '$'
    local formatted = tostring(floor(abs(n)))
    -- insert thousands separators
    local k
    repeat
        formatted, k = formatted:gsub('^(%d+)(%d%d%d)', '%1.%2')
    until k == 0
    return (n < 0 and '-' or '') .. symbol .. formatted
end

--- Distance helpers that work with vector2/vector3/vector4 and plain tables.
function U.Distance(a, b)
    if not a or not b then return math.huge end
    local ax, ay, az = a.x or a[1] or 0, a.y or a[2] or 0, a.z or a[3] or 0
    local bx, by, bz = b.x or b[1] or 0, b.y or b[2] or 0, b.z or b[3] or 0
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function U.Distance2D(a, b)
    if not a or not b then return math.huge end
    local dx = (a.x or a[1] or 0) - (b.x or b[1] or 0)
    local dy = (a.y or a[2] or 0) - (b.y or b[2] or 0)
    return math.sqrt(dx * dx + dy * dy)
end

--- Validate a coordinate table coming from an untrusted source.
function U.IsValidCoords(coords)
    if type(coords) ~= 'table' then return false end
    local x = tonumber(coords.x or coords[1])
    local y = tonumber(coords.y or coords[2])
    local z = tonumber(coords.z or coords[3])
    if not x or not y or not z then return false end
    if x ~= x or y ~= y or z ~= z then return false end
    if abs(x) > 20000 or abs(y) > 20000 or abs(z) > 5000 then return false end
    return true
end

--- Convert a coordinate table into a vector3 (safe on both sides).
function U.ToVec3(coords)
    return vector3(coords.x or coords[1], coords.y or coords[2], coords.z or coords[3])
end

--- Shallow key/value filter used to whitelist incoming NUI payloads.
function U.Pick(source, keys)
    local out = {}
    for i = 1, #keys do
        local k = keys[i]
        if source[k] ~= nil then out[k] = source[k] end
    end
    return out
end

--- Weighted random selection: entries = { { weight = 10, value = ... }, ... }
function U.WeightedPick(entries)
    ensureSeeded()
    local total = 0
    for i = 1, #entries do total = total + (entries[i].weight or 0) end
    if total <= 0 then return nil end
    local roll = random() * total
    for i = 1, #entries do
        roll = roll - (entries[i].weight or 0)
        if roll <= 0 then return entries[i].value end
    end
    return entries[#entries] and entries[#entries].value
end

--- Simple rate limiter bucket, used by server-side validation.
--- Returns true when the call is allowed.
local buckets = {}
function U.RateLimit(key, limit, windowMs)
    local now = nowMs()
    local bucket = buckets[key]
    if not bucket then
        buckets[key] = { count = 1, resetAt = now + windowMs }
        return true
    end
    if now >= bucket.resetAt then
        bucket.count = 1
        bucket.resetAt = now + windowMs
        return true
    end
    bucket.count = bucket.count + 1
    return bucket.count <= limit
end

--- Periodic cleanup so the limiter table cannot grow without bound.
CreateThread(function()
    while true do
        Wait(60000)
        local now = nowMs()
        for key, bucket in pairs(buckets) do
            if now >= bucket.resetAt then buckets[key] = nil end
        end
    end
end)
