local accountRoles = {}

local blacklistedGroupActions = {
    ['addUser'] = true,
    ['removeUser'] = true,
    ['manageUser'] = true,
    ['transferOwnership'] = true,
    ['manageAccount'] = true,
    ['closeAccount'] = true,
}

local function CheckRolePermission(roleName, permission)
    if not roleName then return false end

    local validRole = accountRoles[roleName]

    if not validRole then return false end

    return validRole[permission]
end

---@param player QBX Player
local function CanPerformAction(player, accountId, role, action)
    if CheckRolePermission(role, action) then return true end

    local groupName = SelectAccount(accountId)?.group

    if groupName then
        if blacklistedGroupActions[action] then return false end

        -- TODO : Handle Groups
        local groups = exports.qbx_core:HasGroup(player.PlayerData.source, groupName)
        local groupRole = role

        if CheckRolePermission(role, action) then return true end
    end
end

local function LoadRoles()
    local roles = MySQL.query.await('SELECT * FROM account_roles')
    
    print(json.encode(roles))

    if not roles then lib.print.error('[ox_banking] : No Roles Available. Please Contact Developer') end
 
    for i = 1, #roles do
        local roleData = roles[i]

        local roleName = roleData.name
        
        roleData.name = nil
        roleData.id = nil

        accountRoles[roleName] = roleData

        GlobalState['accountRole.'..roleName] = nil

        GlobalState['accountRole.'..roleName] = roleData
    end

    GlobalState['accountRoles'] = nil
    GlobalState['accountRoles'] = accountRoles
end

LoadRoles()

return {
    CanPerformAction = CanPerformAction,
}