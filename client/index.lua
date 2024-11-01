local hasLoadedUi = false
local isUiOpen = false
local isATMopen = false

local Config = lib.loadJson('data.config')

local function canOpenUi() 
  return IsPedOnFoot(cache.ped) and not IsPedDeadOrDying(cache.ped) and not LocalPlayer.state.isDead
end

local function setupUi() 
    if hasLoadedUi then return end

    local accountRoles = GlobalState.accountRoles

    local permissions = {}

    for roleName, role in pairs(accountRoles) do
        permissions[roleName] = GlobalState['accountRole.'..roleName]
    end

    SendNUIMessage({
        action = "setInitData",
        data = {
            locales = lib.getLocales(),
            permissions = permissions, --json encode ?
        },
    })

    hasLoadedUi = true
end

local function openAtm(entity)
    if not canOpenUi() then return end

    local atmEnter = lib.requestAnimDict('mini@atmenter')

    local atmCoords = GetEntityCoords(entity, false)
    local cX, cY, cZ = atmCoords.x, atmCoords.y, atmCoords.z

    local playerCoords = GetEntityCoords(cache.ped, false)
    local pX, pY, pZ = playerCoords.x, playerCoords.y, playerCoords.z

    local doAnim = (entity and DoesEntityExist(entity) and math.abs((cX - cY) + (cZ - pX) + (pY - pZ)) < 5.0)
    
    if doAnim then
        local x,y,z = GetOffsetFromEntityInWorldCoords(entity, 0, -0.7, 1)
        local heading = GetEntityHeading(entity)
        local sequence = OpenSequenceTask(0)
  
        TaskGoStraightToCoord(0, x, y, z, 1.0, 5000, heading, 0.25)
        TaskPlayAnim(0, atmEnter, 'enter', 4.0, -2.0, 1600, 0, 0.0, false, false, false)
        CloseSequenceTask(sequence)
        TaskPerformSequence(cache.ped, sequence)
        ClearSequenceTask(sequence)
    end

    setupUi()

    Wait(0)

    lib.waitFor(function()
        if GetSequenceProgress(cache.ped) == -1 then return true end
    end, '', false)

    PlaySoundFrontend(-1, 'PIN_BUTTON', 'ATM_SOUNDS', true)

    isUiOpen = true
    isATMopen = true

    SendNUIMessage({
        action = 'openATM',
        data = nil,
    })

    SetNuiFocus(true, true)
    RemoveAnimDict(atmEnter)
end

---@param entity entityId
exports('openAtm', openAtm)

local function openBank() 
    if not canOpenUi() then return end

    setupUi()

    local playerCash = exports.ox_inventory:GetItemCount('money')

    print('PlayerCash ',playerCash)

    isUiOpen = true

    lib.hideTextUI()

    SendNUIMessage({
        action = 'openBank',
        data = {cash = playerCash},
    })
    
    SetNuiFocus(true, true)
end
exports('openBank', openBank)

local banks = lib.loadJson('data.banks')

local atms = lib.loadJson('data.atms')

local atmOptions = {
    name = 'access_atm',
    icon = 'fa-solid fa-money-check',
    label = locale('target_access_atm'),
    onSelect = function(data)
        openAtm(data.entity)
    end,
    distance = 1.3,
}

exports.ox_target.addModel(atms, atmOptions)

RegisterNuiCallback('exit', function(_, cb)
  cb(1)
  SetNuiFocus(false, false)

  isUiOpen = false
  isATMopen = false
end)

AddEventHandler('ox_inventory:itemCount', function(itemName, totalCount) 
    if not (isUiOpen or isATMopen or itemName ~= 'money') then return end

    SendNUIMessage({
        action = 'refreshCharacter',
        data = {cash = totalCount},
    })
end)

local function serverNuiCallback(event)
    RegisterNuiCallback(event, function(data, cb)
        print('NUI Callback Received : '..event..' - '..json.encode(data))
        local callbackName = 'ox_banking:'..event
        local response = lib.callback.await(callbackName, false, data)
        print('Server Callback : '..event..' - '..json.encode(response))
        cb(response)
    end)
end

serverNuiCallback('getDashboardData')
serverNuiCallback('transferOwnership')
serverNuiCallback('manageUser')
serverNuiCallback('removeUser')
serverNuiCallback('getAccountUsers')
serverNuiCallback('addUserToAccount')
serverNuiCallback('getAccounts')
serverNuiCallback('createAccount')
serverNuiCallback('deleteAccount')
serverNuiCallback('depositMoney')
serverNuiCallback('withdrawMoney')
serverNuiCallback('transferMoney')
serverNuiCallback('renameAccount')
serverNuiCallback('convertAccountToShared')
serverNuiCallback('getLogs')
serverNuiCallback('getInvoices')
serverNuiCallback('payInvoice')