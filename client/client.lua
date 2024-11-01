local config = lib.loadJson('data.config')

if config.UseOxTarget then return end

lib.locale()

local function onEnterBank()
    lib.showTextUI(locale('text_ui_access_bank'))
end

local function onExitBank()
    lib.hideTextUI()
end

local function insideBank()
    if IsControlJustPressed(0, 38) then
        exports.ox_banking.openBank()
    end
end

local function createBankBlip(x, y, z)
    local prite, colour, scale = table.unpack(config.BankBlip)

    if not sprite then return end

    local blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, scale)
    SetBlipAsShortRange(blip, true)
    AddTextEntry('ox_banking_bank', locale('bank'))
    BeginTextCommandSetBlipName('ox_banking_bank')
    EndTextCommandSetBlipName(blip)
end

lib.array.forEach(lib.loadJson('data.banks'), function(bank)
    lib.points.new({
        coords = bank.coords,
        distance = 1.5,
        onEnter = onEnterBank,
        onExit = onExitBank,
        nearby = insideBank
    })

    createBankBlip(bank.coords)
end)

local atms = lib.loadJson('data.atms')

for i = 1, #atms do 
    atms[i] = GetHashKey(atms[i]) 
end

local function findClosestAtm()
    if IsNuiFocused() or IsPauseMenuActive() or not IsPedOnFoot(cache.ped) then return end

    local x, y, z = cache.coords.x, cache.coords.y, cache.coords.z

    for i = 1, #atms do
        local atm = GetClosestObjectOfType(x, y, z, 1.5, atms[i], false, false, false)

        if atm > 0 then
            local atmCoords = GetEntityCoords(atm)

            lib.showTextUI(locale('text_ui_access_atm'))

            while #(GetEntityCoords(cache.ped) - atmCoords) <= 1.5 and not IsNuiFocused() and not IsPauseMenuActive() do
                if IsControlJustPressed(0, 38) then
                    exports.ox_banking:openAtm(atm)
                end

                Wait(0)
            end

            lib.hideTextUI()

            return true
        end
    end
end

CreateThread(function()
    while true do
        Wait(findClosestAtm() and 500 or 1000)
    end
end)
