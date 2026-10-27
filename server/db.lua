--[[
    nx_shared / server/db.lua
    Versioned, idempotent migration runner shared by every nx_* resource.

    Design notes
    ------------
    * FiveM cannot list a directory inside a resource, so each resource
      declares its migration files explicitly and in order.
    * Every migration is applied inside a `nx_migrations` bookkeeping table so
      re-running a resource never re-applies a migration.
    * Migrations must be additive (CREATE TABLE IF NOT EXISTS / ADD COLUMN
      guarded). Destructive changes require a separate, explicitly approved
      migration and a tested rollback plan.
    * Statements run sequentially through oxmysql; a failure aborts the
      remaining statements of that file and is reported loudly.
]]

NX = NX or {}
NX.DB = NX.DB or {}

local ready = false

--- Split a .sql file into individual statements, ignoring `--` comment lines.
local function splitStatements(sql)
    local lines = {}
    for line in sql:gmatch('[^\r\n]+') do
        if not line:match('^%s*%-%-') then
            lines[#lines + 1] = line
        end
    end
    local body = table.concat(lines, '\n')
    local statements = {}
    for stmt in body:gmatch('([^;]+);') do
        local trimmed = stmt:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' then statements[#statements + 1] = trimmed end
    end
    local tail = body:match('([^;]+)$')
    if tail then
        local trimmed = tail:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' then statements[#statements + 1] = trimmed end
    end
    return statements
end

--- Ensure the bookkeeping table exists.
local function ensureBookkeeping()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `nx_migrations` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `resource` VARCHAR(64) NOT NULL,
            `file` VARCHAR(128) NOT NULL,
            `checksum` CHAR(40) DEFAULT NULL,
            `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_resource_file` (`resource`, `file`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

local function isApplied(resourceName, file)
    local row = MySQL.single.await(
        'SELECT `id` FROM `nx_migrations` WHERE `resource` = ? AND `file` = ? LIMIT 1',
        { resourceName, file }
    )
    return row ~= nil
end

--- Apply a single migration file.
local function applyFile(resourceName, folder, file)
    local path = ('%s/%s'):format(folder, file)
    local sql = LoadResourceFile(resourceName, path)
    if not sql or sql == '' then
        print(('^1[nx_shared] migration file missing or empty: %s:%s^7'):format(resourceName, path))
        return false
    end

    local statements = splitStatements(sql)
    if #statements == 0 then
        print(('^3[nx_shared] migration %s:%s contains no statements^7'):format(resourceName, path))
        return true
    end

    for index, statement in ipairs(statements) do
        local ok, err = pcall(function()
            MySQL.query.await(statement)
        end)
        if not ok then
            print(('^1[nx_shared] migration failed %s:%s (statement %d/%d): %s^7')
                :format(resourceName, path, index, #statements, tostring(err)))
            return false
        end
    end

    MySQL.insert.await(
        'INSERT IGNORE INTO `nx_migrations` (`resource`, `file`) VALUES (?, ?)',
        { resourceName, file }
    )
    print(('^2[nx_shared] applied migration %s/%s^7'):format(resourceName, file))
    return true
end

--- Public migration entry point.
--- @param resourceName string  the resource that owns the migrations
--- @param folder string        folder inside that resource, e.g. 'server/migrations'
--- @param files string[]       ordered list of .sql files
--- @return boolean success
local function migrate(resourceName, folder, files)
    if type(resourceName) ~= 'string' or type(files) ~= 'table' then return false end
    local ok, err = pcall(ensureBookkeeping)
    if not ok then
        print(('^1[nx_shared] could not prepare migration bookkeeping: %s^7'):format(tostring(err)))
        return false
    end
    for _, file in ipairs(files) do
        if not isApplied(resourceName, file) then
            if not applyFile(resourceName, folder, file) then return false end
        end
    end
    return true
end

exports('Migrate', migrate)
exports('DBReady', function() return ready end)

--- Small convenience wrappers so gameplay code does not depend on oxmysql
--- specifics directly (keeps a single place to change the driver later).
NX.DB = {
    Query = function(query, params) return MySQL.query.await(query, params or {}) end,
    Single = function(query, params) return MySQL.single.await(query, params or {}) end,
    Insert = function(query, params) return MySQL.insert.await(query, params or {}) end,
    Update = function(query, params) return MySQL.update.await(query, params or {}) end,
    Scalar = function(query, params) return MySQL.scalar.await(query, params or {}) end,
}

--- nx_shared owns the foundational schema.
local SHARED_MIGRATIONS = {
    '001_init.sql',
}

CreateThread(function()
    -- Give oxmysql a moment to establish its pool after a cold start.
    local attempts = 0
    while GetResourceState('oxmysql') ~= 'started' and attempts < 60 do
        attempts = attempts + 1
        Wait(250)
    end

    if GetResourceState('oxmysql') ~= 'started' then
        print('^1[nx_shared] oxmysql is not started — NOVARA CITY database features are unavailable.^7')
        return
    end

    ready = migrate(GetCurrentResourceName(), 'server/migrations', SHARED_MIGRATIONS)
    if ready then
        print(('^2[nx_shared] database ready (schema v%s)^7'):format(#SHARED_MIGRATIONS))
        TriggerEvent('nx_shared:server:dbReady')
    else
        print('^1[nx_shared] database migrations did not complete — check the errors above.^7')
    end
end)
