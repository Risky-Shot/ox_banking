
# OX-BANKING for QBOX [BETA]

This is modified version of [ox_banking](https://github.com/overextended/ox_banking) for QBOX Framework

## REQUIREMENTS
- Intermediate Knowledge of Lua, TypeScript, SQL, QBOX and Ox Core

## INSTALLATION
- Download Release from [here](https://github.com/Risky-Shot/ox_banking?tab=readme-ov-file#build)
- Make sure Collation for QBOX Database and every column is `utf8mb4_unicode_ci` (For Foreign Keys Setup.)
- Run [install.sql]() file in your database.
    > EXTRA : Modify Roles Permissions in `account_roles` table as per your need.
- Make following changes in `qbox_core/shared/jobs.lua` & `qbox_core/shared/gangs.lua`
    > Add `hasAccount = true,` before `grades` if you would like an account to be created for this group. (Default : No)
    
    > change `bankAuth` values to one of the roles available in `account_roles` table
- Modify this callback to create a default account on player creation. `qbx_core/character.lua`
```
lib.callback.register('qbx_core:server:createCharacter', function(source, data)
    local newData = {}
    newData.charinfo = data

    local success = Login(source, nil, newData)
    if not success then return end

    giveStarterItems(source)

    if GetResourceState('qbx_spawn') == 'missing' then
        SetPlayerBucket(source, 0)
    end

    local player = exports.qbx_core:GetPlayer(source)

    if not player then return end

    local citizenid = player.PlayerData.citizenid

    local account = exports.ox_banking:CreateAccount(citizenid, "Personal", true)

    if not account then 
        lib.print.info('Failed to Create Bank Account. Please contact staff to fix this issue.')
        return 
    end

    local STARTER_AMOUNT = 1000 -- Starter Balance of Player default account

    account:addBalance(STARTER_AMOUNT, 'State Welfare')

    lib.print.info(('%s has created a character'):format(GetPlayerName(source)))
    return newData
end)
```

## BUILD
If you wish to edit any of the UI elements you will need to download the source code, edit what you need and then compile it.

**Requirements:**
- Node.js (LTS)
- pnpm

**Installing Node.js:**
- Download the LTS version of Node.js.
- Go through the install and make sure you install all of the features.
- Run node --version in cmd and make sure that it gives you the version number. If it doesn't then you didn't install it correctly.

**Installing pnpm:**
- After installing NodeJS you can install pnpm by running npm install -g pnpm.

**Building the UI:**

- cd into the web directory.
- run `pnpm i` to install the dependencies.
- run `pnpm build` to build the source files.

```
When working in the browser you can run pnpm start, which supports hot reloads meaning that you will see your changes after saving your file.
If you want to work in game you can run pnpm start:game which writes changes to disk, so the only thing you have to do is restart the resource for it take affect.
```
