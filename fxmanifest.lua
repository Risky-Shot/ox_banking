name 'ox_banking'
author 'Overextended | RiskyShot'
version '0.0.1'
description 'Banking system for qbox.'


fx_version 'cerulean'
game 'gta5'

lua54 'yes'

dependencies {
    '/server:7290',
    '/onesync',
}

ox_lib 'locale'

ui_page 'web/build/index.html'


shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/index.lua',
    'client/client.lua',
    'client/invoice.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/utils.js',
    'server/core/db.lua',
    'server/core/index.lua',
    'server/index.lua'
}

files {
	'web/build/index.html',
    'web/build/**/*',
	'data/atms.json',
	'data/banks.json',
	'data/config.json',
	'locales/en.json',
}
