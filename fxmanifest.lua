fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'codex_diving'
author 'Codex Dev'
description 'Advanced diving for Qbox'
version '3.0.1'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'data/cooldowns.json'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'qbx_core'
}
