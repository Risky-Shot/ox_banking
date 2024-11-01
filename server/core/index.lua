-- Return the default account for a character.
---@param cid citizenid
function GetCharacterAccount(cid)
    local charId = cid

    local accountId = charId and SelectDefaultAccountId('owner', charId)

    print('GetCharacterAccount | Default Account : '..accountId)
    return accountId and OxAccount.get(accountId) or nil
end

-- Return the default account for a group.
function GetGroupAccount(groupName)
    local accountId = SelectDefaultAccountId('group', groupName)
    return accountId and OxAccount.get(accountId) or nil
end

-- Create New Account
function CreateAccount(owner, label, isDefault)
    local accountId = CreateNewAccount(owner, label, isDefault)

    return OxAccount.get(accountId)
end

-- 
function PayAccountInvoice(invoiceId, charId)
    return UpdateInvoice(invoiceId, charId)
end

function DeleteAccountInvoice(invoiceId) 
    return DeleteInvoice(invoiceId)
end

exports('GetCharacterAccount', GetCharacterAccount)
exports('GetGroupAccount', GetGroupAccount)
exports('CreateAccount', CreateAccount)
exports('PayAccountInvoice', PayAccountInvoice)
exports('DeleteAccountInvoice', DeleteAccountInvoice)