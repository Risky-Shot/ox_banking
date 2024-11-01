local function CreateInvoice()
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
            icon = 'building-columns',
            placeholder = 'Select Account',
            options = ownedAccounts,
            required = true
        },
        {
            type = 'input',
            icon = 'building-columns',
            label = 'Target Account',
            placeholder = 'Account Id...',
            required = true
        },
        {
            type = 'input',
            label = 'Reciever Citizen ID',
            icon = 'user',
            description = 'Check if citizen is member of account.',
            placeholder = 'Citizen ID...',
            required = true
        },
        {
            type = 'number',
            label = 'Amount',
            icon = 'sack-dollar',
            placeholder = '$...',
            min = 1,
            precision = 2,
            required = true
        },
        {
            type = 'input',
            label = 'Note',
            icon = 'comment-dots',
            placeholder = 'Something to remind...',
            default = 'Invoice',
            required = true
        },
        {
            type = 'date',
            label = 'Due Date',
            icon = 'calendar',
            description = 'Default Time : 00:00 (24-hr)',
            format = 'YYYY-MM-DD',
            returnString = true,
            default = true,
            required = true,
            clearable = false
        }
    })

    if not input then return end

    local data = {
        fromAccount = input[1],
        toAccount = input[2],
        receiver = input[3],
        amount = input[4],
        message = input[5],
        dueDate = input[6]..' 00:00:00'
    }

    local response = lib.callback.await('ox_banking:createInvoice', false, data)

    if not response.success then
        lib.notify({
            title = 'Banking Invoice',
            description = response.message,
            duration = 5000
        })
    else
        lib.notify({
            title = 'Banking Invoice',
            description = 'Invoice Sent.',
            duration = 5000
        })
    end
end

local function UnPaidInvoice()
    local invoices = lib.callback.await('ox_banking:getPersonalInvoices', false)

    print(json.encode(invoices))

    if #invoices < 1 then 
        lib.notify({
            title = 'Banking Invoice',
            description = 'No Unpaid Invoices For Personal Account.'
        })
        return 
    end

    local options = {}

    for i=1, #invoices do
        local invoice = invoices[i]

        options[#options + 1] = {
            title = invoice.label,
            description = 'Pay Invoice',
            arrow = true,
            metadata = {
                {
                    label = 'Amount',
                    value = '$ '..invoice.amount
                },
                {
                    label = 'Note',
                    value = invoice.message
                },
                {
                    label = 'Sent By',
                    value = invoice.sentBy
                },
                {
                    label = 'Due Date',
                    value = exports.ox_banking:formatDate(invoice.dueDate)
                },
                {
                    label = 'Sent At',
                    value = exports.ox_banking:formatDate(invoice.sentAt)
                }
            },
            onSelect = function()
                local alert = lib.alertDialog({
                    header = 'Pay Invoice',
                    content = invoice.label..'  \nAmount : $ '..invoice.amount
                })
            end
        }
    end

    lib.registerContext({
        id = 'ox_banking:unpaidInvoices',
        title = 'Unpaid Invoices',
        menu = 'ox_banking:invoiceDialog',
        options = options
    })

    lib.showContext('ox_banking:unpaidInvoices')
end

local function OpenDialog()
    lib.registerContext({
        id = 'ox_banking:invoiceDialog',
        title = 'Invoice Manager',
        options = {
            {
                title = 'Personal Invoices',
                description = 'View Unpaid Personal Invoices',
                icon = 'receipt',
                onSelect = function()
                    UnPaidInvoice()
                end
            },
            {
                title = 'Send Invoice',
                description = 'Send Invoice to another account.',
                icon = 'file-invoice-dollar',
                onSelect = function()
                    CreateInvoice()
                end
            }
        }
    })

    lib.showContext('ox_banking:invoiceDialog')
end

RegisterNetEvent("ox_banking:openInvoiceDialog", function()
    OpenDialog()
end)