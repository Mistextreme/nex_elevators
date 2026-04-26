fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nex_elevators'
author 'NEX Development | Donk'
version '1.0.0'
description 'Premium Elevator System with Custom UI | Multi-Framework'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'bridge/framework.lua',
    'client/cl_main.lua',
}

server_scripts {
    'bridge/sv_framework.lua',
    'server/sv_storage.lua',
    'server/sv_main.lua',
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/build/fonts/*.ttf',
}

escrow_ignore {
    'config.lua',
}

dependency '/assetpacks'