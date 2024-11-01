local OxAccount = require 'server.core.class'
local CanPerformAction = require 'server.core.roles'.CanPerformAction

local addBalance = 'UPDATE accounts SET balance = balance + ? WHERE id = ?'
local removeBalance = 'UPDATE accounts SET balance = balance - ? WHERE id = ?'
local safeRemoveBalance = removeBalance..' AND (balance - ?) >= 0'
local addTransaction = 'INSERT INTO accounts_transactions (actorId, fromId, toId, amount, message, note, fromBalance, toBalance) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
local getBalance = 'SELECT balance FROM accounts WHERE id = ?'
local doesAccountExist = 'SELECT 1 FROM accounts WHERE id = ?'
local selectAccountRole = 'SELECT role FROM accounts_access WHERE accountId = ? AND charId = ?'

local function GenerateAccountId()
    local date = os.date("*t")                 -- Get the current date as a table
    local year = tostring(date.year):sub(-2)    -- Get the last two digits of the year
    local month = string.format("%02d", date.month)  -- Format month as a two-digit string
    local day = string.format("%02d", date.day)
    local baseId = tonumber(year .. month..day)    -- Concatenate and multiply by 1000

    local accountId = lib.waitFor(function()
        ::REPEAT::
        local accountId = baseId .. tostring(math.random(10, 99) * 100 + math.random(0, 999))

        -- Fail Safe To not exceed 10 characters
        if #accountId > 10 then goto REPEAT end

        local existingId = MySQL.scalar.await(doesAccountExist, {
            accountId
        })

        if not existingId then return accountId end
    end, nil, false)

    return accountId
end

function UpdateBalance(id, amount, action, overdraw, message, note, actorId)
    amount = tonumber(amount)

    if not amount then return { success = false, message = 'amount_not_number'} end

    local balance = MySQL.scalar.await(getBalance, {
        id
    })

    if not balance then return {sucess = false, message = 'no_balance'} end

    local addAction = action == 'add'

    local success = false

    if addAction then
        success = MySQL.update.await(addBalance, {
            amount, id
        })
    else
        success = MySQL.update.await(overdraw and removeBalance or safeRemoveBalance , {
            amount, id, amount
        })
    end

    if not success then return {success = false, message = 'something_went_wrong'} end

    local didUpdate = false

    local ADD_TRANSACTION = {
        'INSERT INTO accounts_transactions (actorId, fromId, toId, amount, message, note, fromBalance, toBalance) VALUES (@actorId, @fromId, @toId, @amount, @message, @note, @fromBalance, @toBalance)'
    }
    
    local values = {
        actorId = actorId,
        fromId = addAction and nil or id,
        toId = addAction and id or nil,
        amount = amount,
        message = message,
        note = note,
        fromBalance = addAction and nil or (balance - amount),
        toBalance = addAction and (balance + amount) or nil
    }

    -- Updated Query as sometimes it was not being executed

    didUpdate = MySQL.transaction.await(ADD_TRANSACTION , values)

    if not didUpdate then return {success = false, message = 'something_went_wrong'} end

    return {success = true}
end

function PerformTransaction(fromId, toId, amount, overdraw, message, note, actorId)
    amount = tonumber(amount)

    if not amount then return { success = false, message = 'amount_not_number'} end

    local fromBalance = MySQL.scalar.await(getBalance, {
        fromId
    })

    local toBalance = MySQL.scalar.await(getBalance, {
        toId
    })

    if not fromBalance or not toBalance then return {sucess = false, message = 'no_balance'} end

    local removedBalance = nil
    
    if overdraw then
        removedBalance = MySQL.update.await(removeBalance, {
            amount, fromId
        })
    else
        removedBalance = MySQL.update.await(safeRemoveBalance, {
            amount, fromId, amount
        })
    end

    if removeBalance then
        local addBalance = MySQL.update.await(addBalance, {
            amount, toId
        })

        if addBalance then
            MySQL.rawExecute.await(addTransaction, {
                actorId,
                fromId,
                toId,
                amount,
                message or locale('transfer'),
                note,
                fromBalance - amount,
                toBalance + amount
            })
            return {success = true}
        end
    end

    return {success = false, message = 'something_went_wrong'}
end

---@param column owner | group | id
---@param id number | string
function SelectAccounts(column, id)
    local response = nil

    if column == 'owner' then
        response = MySQL.single.await('SELECT * FROM accounts WHERE `owner` = ?', {
            id
        })
    elseif column == 'group' then
        response = MySQL.single.await('SELECT * FROM accounts WHERE `group` = ?', {
            id
        })
    elseif column == 'id' then
        response = MySQL.single.await('SELECT * FROM accounts WHERE `id` = ?', {
            id
        })
    end

    return response
end

---@param column owner | group | id
---@param id number | string
function SelectDefaultAccountId(column, id)
    local response = nil

    if column == 'owner' then
        response = MySQL.single.await('SELECT `id` FROM accounts WHERE `owner` = ? AND isDefault = 1', {
            id
        })
    elseif column == 'group' then
        response = MySQL.single.await('SELECT `id` FROM accounts WHERE `group` = ? AND isDefault = 1', {
            id
        })
    elseif column == 'id' then
        response = MySQL.single.await('SELECT `id` FROM accounts WHERE `id` = ? AND isDefault = 1', {
            id
        })
    end

    print('SelectDefaultAccountId | '..id..' | '..json.encode(response))

    return response.id
end

---@param column owner | group | id
---@param id number | string
function SelectAccount(id)
    local response = SelectAccounts('id', id)

    return response
end


function IsAccountIdAvailable(id)
    local row = MySQL.single.await(doesAccountExist, {
        id
    })
    
    return not row
end

function CreateNewAccount(owner, label, isDefault)
    local accountId = GenerateAccountId()

    local player = exports.qbx_core:GetPlayerByCitizenId(owner)

    local column = 'group'

    local result = nil

    if player then column = 'owner' end -- Check if Owner is CitizenId (could be exploited ?)

    if column == 'group' then
        result = MySQL.insert.await('INSERT INTO accounts (`id`, `label`, `group`, `type`, `isDefault`) VALUES (?, ?, ?, ?, ?)', {
            accountId, label, owner, 'group', isDefault or 0
        })
    elseif column == 'owner' then
        result = MySQL.insert.await('INSERT INTO accounts (`id`, `label`, `owner`, `type`, `isDefault`) VALUES (?, ?, ?, ?, ?)', {
            accountId, label, owner, 'personal', isDefault or 0
        })
    end

    if result and column == 'owner' then
        MySQL.insert.await('INSERT INTO accounts_access (accountId, charId, role) VALUES (?, ?, ?)', {
            accountId, owner, 'owner'
        })
    end

    return accountId
end

function DeleteAccount(accountId)
    local success = MySQL.update.await('UPDATE accounts SET type = `inactive` WHERE id = ?', {
        accountId
    })

    if not success then
        return {success = false, message = 'something_went_wrong'}
    end

    return {success = true}
end


function SelectAccountRole(accountId, charId) 
    local response = MySQL.single.await(selectAccountRole, {
        accountId, charId
    })

    return response.role
end

---@param playerId source number
function DepositMoney(playerId, accountId, amount, message, note)
    amount = tonumber(amount)

    if not amount then return { success = false, message = 'amount_not_number'} end

    local player = exports.qbx_core:GetPlayer(playerId)

    if not player then return { success = false, message = 'no_charid'} end

    local charId =  player.PlayerData.citizenid

    local money = exports.ox_inventory:GetItemCount(playerId, 'money')

    print('Amount : '..amount..' | Money : '..money)

    if amount > money then return { success = false, message = 'insufficient_funds'} end

    local balance = MySQL.scalar.await(getBalance, {accountId..'K'})

    if not balance then return {sucess = false, message = 'no_balance'} end

    local role = SelectAccountRole(accountId, charId)

    if not CanPerformAction(player, accountId, role, 'deposit') then
        return {success = false, message = 'no_access'}
    end

    local affectedRows = MySQL.update.await(addBalance, {
        amount, accountId
    })

    if not affectedRows or not exports.ox_inventory:RemoveItem(playerId, 'money', amount) then
        return {success = false, message = 'something_went_wrong'}
    end

    MySQL.rawExecute.await(addTransaction, {
        charId, nil, accountId, amount, message or locale('deposit'), note, nil, balance+amount
    })

    return {success = true}
end

---@param playerId source number
function WithdrawMoney(playerId, accountId, amount, message, note)
    amount = tonumber(amount)

    if not amount then return { success = false, message = 'amount_not_number'} end

    local player = exports.qbx_core:GetPlayer(playerId)

    if not player then return { success = false, message = 'no_charid'} end

    local charId =  player.PlayerData.citizenid

    local role = SelectAccountRole(accountId, charId)

    if not CanPerformAction(player, accountId, role, 'deposit') then
        return {success = false, message = 'no_access'}
    end

    local balance = MySQL.scalar.await(getBalance, {
        accountId
    })

    if not balance then return {sucess = false, message = 'no_balance'} end

    local affectedRows = MySQL.update.await(safeRemoveBalance, {
        amount, accountId, amount
    })

    if not affectedRows or not exports.ox_inventory:AddItem(playerId, 'money', amount) then
        return {success = false, message = 'something_went_wrong'}
    end

    MySQL.rawExecute.await(addTransaction, {
        charId, accountId, nil, amount, message or locale('withdraw'), note, balance-amount, nil
    })

    return {success = true}
end

---@param id citizenId
function UpdateAccountAccess(accountId, id, role)
    if not role then
        local affectedRows = MySQL.update.await('DELETE FROM accounts_access WHERE accountId = ? and charId = ?', {accountId, id})

        if affectedRows < 1 then
            return {success = false, message = 'something_went_wrong'}
        end

        return {success = true}
    end

    local updated = MySQL.insert.await('INSERT INTO accounts_access (accountId, charId, role) VALUE (?, ?, ?) ON DUPLICATE KEY UPDATE role = VALUES(role)', 
        {accountId, id, role}
    )

    if not updated then return {success = false, message = 'something_went_wrong'} end

    return {success = true}
end

---@param charId citizenId
function UpdateInvoice(invoiceId, charId)
    local player = exports.qbx_core:GetPlayerByCitizenId(charId)

    if not player then return {success = false, message = 'no_charId'} end

    local invoice = MySQL.single.await('SELECT * FROM accounts_invoices WHERE id = ?', {invoiceId})

    if not invoice then return {success = false, message = 'no_invoice'} end

    if invoice.payerId then return {success = false, message = 'invoice_paid'} end

    local account = OxAccount.get(invoice.toAccount)

    local hasPermission = account:playerHasPermission(player.PlayerData.source, 'payInvoice')

    if not hasPermission then return {success = false, message = 'no_permission'} end

    local updateReceiver = UpdateBalance(invoice.toAccount, invoice.amount, 'remove', false, locale('invoice_payment'), nil, charId)

    if not updateReceiver.success then return {success = false, message = 'no_balance'} end

    local updateSender = UpdateBalance(invoice.fromAccount, invoice.amount, 'add', false, locale('invoice_payment'), nil, charId)

    if not updateSender.success then return {success = false, message = 'no_balance'} end

    local affectedRows = MySQL.update.await('UPDATE accounts_invoices SET payerId = ?, paidAt = ? WHERE id = ?', {
        player.PlayerData.citizenid, os.date("%Y-%m-%d %H:%M:%S"), invoiceId
    })

    if affectedRows < 1 then return {success = false, messge = 'invoice_not_updated'} end

    invoice.payerId = charId

    TriggerEvent('ox:invoicePaid', invoice)

    return {success = true}
end

function CreateInvoice(invoice)
    if invoice.actorId then
        local player = exports.qbx_core:GetPlayerByCitizenId(invoice.actorId)

        if not player then return {success = false, message = 'no_charId'} end

        local account = OxAccount.get(invoice.fromAccount)

        local hasPermission = account:playerHasPermission(player.PlayerData.source, 'sendInvoice')

        if not hasPermission then return {success = false, message = 'no_permission'} end
    end

    local targetAccount = OxAccount.get(invoice.toAccount)

    if not targetAccount then return {success = false, message = 'no_target_account'} end

    local success = MySQL.insert.await('INSERT INTO accounts_invoices (actorId, fromAccount, toAccount, amount, message, dueDate) VALUES (?, ?, ?, ?, ?, ?)', {
        invoice.actorId, invoice.fromAccount, invoice.toAccount, invoice.amount, invoice.message, invoice.dueDate
    })

    if not success then return {success = false, message = 'invoice_insert_error'} end

    return {success = true}
end

function DeleteInvoice(invoiceId)
    local success = MySQL.update.await('DELETE FROM accounts_invoices WHERE id = ?', {
        invoiceId
    })

    if not success then return {success = false, message = 'invoice_delete_error'} end

    return {success = true}
end

function SetAccountType(accountId, acType)
    local success = MySQL.update.await('UPDATE accounts SET type = ? WHERE id = ?', {
        acType, accountId
    })

    if not success then return {success = false, message = 'update_account_error'} end

    return {success = true}
end