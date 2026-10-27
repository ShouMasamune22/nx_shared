--[[
    NOVARA CITY RP — nx_shared
    Shared configuration, utilities, localization and migration runner.
    Loaded on both client and server. No gameplay logic lives here.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nx_shared'
author 'NOVARA CITY'
description 'Shared configuration, utilities, localization and versioned migrations for NOVARA CITY RP'
version '0.1.0'

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua',
    'shared/logger.lua',
    'shared/locale.lua',
    'shared/bridge.lua',
    'locales/id.lua',
    'locales/en.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
}

files {
    'server/migrations/*.sql',
}

dependency 'oxmysql'
