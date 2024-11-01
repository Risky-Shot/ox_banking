local CanPerformAction = require 'server.core.roles'.CanPerformAction

OxAccount = {}
OxAccount.__index = OxAccount
OxAccount.members = {}

-- Static Methods
function OxAccount.get(accountId)
    if OxAccount.members[accountId] then
        return OxAccount.members[accountId]
    end

    local validAccount = SelectAccount(accountId)
    if not validAccount then
        lib.print.error("No account exists with accountId " .. accountId)
        return
    end

    return OxAccount.new(accountId)
end

function OxAccount.getAll()
    return OxAccount.members
end

-- Constructor
function OxAccount.new(accountId)
    local self = setmetatable({}, OxAccount)
    self.accountId = accountId
    OxAccount.members[accountId] = self
    return self
end

-- Instance Methods

function OxAccount:getMeta(key)
    local metadata = SelectAccount(self.accountId)
    
    print('Metadata : '..self.accountId.. " | "..json.encode(metadata))
    if not metadata then return nil end

    if type(key) == "table" then
        local result = {}
        for _, k in ipairs(key) do
            result[k] = metadata[k]
        end
        return result
    else
        return metadata[key]
    end
end

function OxAccount:addBalance(amount, message)
    return UpdateBalance(self.accountId, amount, "add", false, message)
end

function OxAccount:removeBalance(amount, message, overdraw)
    overdraw = overdraw or false
    return UpdateBalance(self.accountId, amount, "remove", overdraw, message)
end

---@param {toId, amount, overdraw, message, note, actorId}
function OxAccount:transferBalance(data)
    data.overdraw = data.overdraw or false
    data.message = data.message or locale('transfer')
    data.note = data.note or nil
    data.actorId = data.actorId or nil
    return PerformTransaction(self.accountId, data.toId, data.amount, data.overdraw, data.message, data.note, data.actorId)
end

function OxAccount:depositMoney(playerId, amount, message, note)
    return DepositMoney(playerId, self.accountId, amount, message, note)
end

function OxAccount:withdrawMoney(playerId, amount, message, note)
    return WithdrawMoney(playerId, self.accountId, amount, message, note)
end

function OxAccount:deleteAccount()
    return DeleteAccount(self.accountId)
end

function OxAccount:getCharacterRole(id)
    local charId = id
    if not charId then return nil end
    return SelectAccountRole(self.accountId, charId)
end

function OxAccount:setCharacterRole(id, role)
    local charId = id
    if not charId then return nil end
    return UpdateAccountAccess(self.accountId, charId, role)
end

function OxAccount:playerHasPermission(playerId, permission)
    print('OxAccount:playerHasPermission | ', playerId ,' | ',permission)
    local player = exports.qbx_core:GetPlayer(playerId)

    if not player or not player.PlayerData.citizenid then 
        return false 
    end

    local role = self:getCharacterRole(player.PlayerData.citizenid)

    return CanPerformAction(player, self.accountId, role, permission)
end

function OxAccount:setShared()
    return SetAccountType(self.accountId, "shared")
end

function OxAccount:createInvoice(data)
    local invoice = { fromAccount = self.accountId }
    for k, v in pairs(data) do
        print(k,v)
        invoice[k] = v
    end

    return CreateInvoice(invoice)
end

return OxAccount