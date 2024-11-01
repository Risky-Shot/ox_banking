local function OpenDialog()
    local ownedAccounts = lib.callback.await('ox_banking:fetchAccountsForSendInvoice', false)

    if #ownedAccounts < 1 then 
        lib.notify({
            title = 'Banking Invoice',
            description = 'No Accounts with Send Invoice Permissions.'
        })
        return 
    end

     local input = lib.inputDialog('Create Invoice', {
        {
            type = 'select',
            label = 'My Account',
            placeholder = 'Select Account',
            options = ownedAccounts,
            required = true
        },
        {
            type = 'input',
            label = 'Target Account',
            placeholder = 'Account Id...',
            required = true
        },
        {
            type = 'input',
            label = 'Reciever Citizen ID',
            description = 'Check if citizen is member of account.',
            placeholder = 'Citizen ID...',
            required = true
        },
        {
            type = 'number',
            label = 'Amount',
            placeholder = '$...',
            min = 1,
            precision = 2,
            required = true
        },
        {
            type = 'input',
            label = 'Note',
            placeholder = 'Something to remind...',
            default = 'Invoice',
            required = true
        },
        {
            type = 'date',
            label = 'Due Date',
            format = 'YYYY-MM-DD',
            returnString = true,
            default = true,
            required = true
        }
    })

    print(json.encode(input, {indent = true}))
    if not input then return end

    local data = {
        fromAccount = input[1],
        toAccount = input[2],
        receiver = input[3],
        amount = input[4],
        message = input[5],
        dueDate = input[6]
    }

    local response = lib.callback.await('ox_banking:createInvoice', false, data)

    print('Invoice Status ',json.encode(response))
end

RegisterNetEvent("ox_banking:openInvoiceDialog", function()
    OpenDialog()
end)