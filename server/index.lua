local function GetPlayerCID(source)
    local player = exports.qbx_core:GetPlayer(source)

    if not player then 
        lib.print.error('GetPlayerCID : Player Not Found')
        return false 
    end

    return player.PlayerData.citizenid
end

lib.callback.register('ox_banking:getAccounts', function(source)
    local charId = GetPlayerCID(source)

    if not charId then 
        lib.print.error('[ox_banking] : Character ID not found.')
        return 
    end

    local query1 = [[
        SELECT DISTINCT 
            COALESCE(access.role, gg.accountRole) AS role, 
            account.*, 
            COALESCE(
                c.fullName, 
                g.label
            ) AS ownerName 
        FROM 
            accounts account 
            LEFT JOIN players c ON account.owner = c.citizenid 
            LEFT JOIN ox_groups g ON account.group = g.name 
            LEFT JOIN player_groups cg ON cg.citizenid = ? AND cg.group = account.group 
            LEFT JOIN ox_group_grades gg ON account.group = gg.group AND cg.grade = gg.grade 
            LEFT JOIN accounts_access access ON account.id = access.accountId AND access.charId = ? 
        WHERE 
            account.type != 'inactive' 
            AND ( access.charId = ? OR ( account.group IS NOT NULL AND gg.accountRole IS NOT NULL)) 
        GROUP BY 
            account.id 
        ORDER BY 
            account.owner = ? DESC, 
            account.isDefault DESC;
    ]]

    local response = MySQL.rawExecute.await(query1, {
        charId, charId, charId, charId
    })

    local accounts = {}

    for i=1, #response do
        local account = response[i]
        accounts[#accounts + 1] = {
            group = account.group,
            id = account.id,
            label = account.label,
            isDefault = charId == account.owner and account.isDefault or false,
            balance = account.balance,
            type = account.type,
            owner = account.ownerName,
            role = account.role,
        }
    end

    return accounts
end)

---@param source playerId
---@param data {name, shared}
lib.callback.register('ox_banking:createAccount', function(source, data)
    local charId = GetPlayerCID(source)

    if not charId then 
        lib.print.error('[ox_banking] : Character ID not found.')
        return 
    end

    if not (data or data.name or data.shared) then 
        lib.print.error('[ox_banking] : Invalid/Incomplete Data Found for Create Account.')
        return 
    end

    local account = CreateAccount(charId, data.name)

    if data.shared then account:setShared() end

    return account.accountId
end)

lib.callback.register('ox_banking:deleteAccount', function(source, accountId)
    local account = OxAccount.get(accountId)
    local balance = account:getMeta('balance')

    if balance > 0 then return end

    local hasPermission = account:playerHasPermission(source, 'closeAccount')

    if not hasPermission then return end

    return account:deleteAccount()
end)

---@param data {accountId, amount}
lib.callback.register('ox_banking:depositMoney', function(source, data)
    local account = OxAccount.get(data.accountId)
    return account:depositMoney(source, data.amount)
end)

---@param data {accountId, amount}
lib.callback.register('ox_banking:withdrawMoney', function(source, data)
    local account = OxAccount.get(data.accountId)
    return account:withdrawMoney(source, data.amount)
end)

---@param data {fromAccountId, target, transferType, amount}
lib.callback.register('ox_banking:transferMoney', function(source, data)
    local account = OxAccount.get(data.fromAccountId)

    local hasPermission = account:playerHasPermission(source, 'withdraw')

    if not hasPermission then return end

    local targetAccountId = nil
    
    targetAccountId = data.transferType == 'account' and OxAccount.get(data.target)?.accountId or GetCharacterAccount(data.target)?.accountId
    
    if data.transferType == 'person' and not targetAccountId then
        return {success= false, message= 'state_id_not_exists'}
    end

    if not targetAccountId then
        return { success = false, message = 'account_id_not_exists'}
    end

    if account.accountId == targetAccountId then
        return { success = false, message = 'same_account_transfer'}
    end

    local charId = GetPlayerCID(source)

    local resp = account:transferBalance({ toId = targetAccountId, amount = data.amount, actorId = charId})
    return resp
end)

lib.callback.register('ox_banking:getDashboardData', function(source)
    lib.print.info('getDashboardData: Called')
    local charId = GetPlayerCID(source)

    lib.print.info('getDashboardData: CharId '..charId)

    local account = GetCharacterAccount(charId)

    if not account then 
        lib.print.error('getDashboardData : No Character Accound Found')
        return 
    end
    local overviewQuery = [[
        SELECT
            LOWER(DAYNAME(d.date)) as day,
            CAST(COALESCE(SUM(CASE WHEN at.toId = ? THEN at.amount ELSE 0 END), 0) AS UNSIGNED) as income,
            CAST(COALESCE(SUM(CASE WHEN at.fromId = ? THEN at.amount ELSE 0 END), 0) AS UNSIGNED) as expenses
        FROM (
            SELECT CURDATE() as date
            UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 1 DAY)
            UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 2 DAY)
            UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 3 DAY)
            UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 4 DAY)
            UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 5 DAY)
            UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 6 DAY)
        ) d
        LEFT JOIN accounts_transactions at ON d.date = DATE(at.date) AND (at.toId = ? OR at.fromId = ?)
        GROUP BY d.date
        ORDER BY d.date ASC
    ]]
    local overview = MySQL.rawExecute.await(overviewQuery,{account.accountId, account.accountId, account.accountId, account.accountId})

    local transactionsQuery = [[
        SELECT id, amount, UNIX_TIMESTAMP(date) as date, toId, fromId, message,
        CASE
            WHEN toId = ? THEN 'inbound'
            ELSE 'outbound'
        END AS 'type'
        FROM accounts_transactions
        WHERE toId = ? OR fromId = ?
        ORDER BY id DESC
        LIMIT 5
    ]]
    local transactions = MySQL.rawExecute.await(transactionsQuery, {account.accountId, account.accountId, account.accountId})

    local invoicesQuery = [[
        SELECT ai.id, ai.amount, UNIX_TIMESTAMP(ai.dueDate) as dueDate, UNIX_TIMESTAMP(ai.paidAt) as paidAt, CONCAT(a.label, ' - ', IFNULL(co.fullName, g.label)) AS label,
        CASE
            WHEN ai.payerId IS NOT NULL THEN 'paid'
            WHEN NOW() > ai.dueDate THEN 'overdue'
            ELSE 'unpaid'
        END AS status
        FROM accounts_invoices ai
        LEFT JOIN accounts a ON a.id = ai.fromAccount
        LEFT JOIN players co ON (a.owner IS NOT NULL AND co.citizenid = a.owner)
        LEFT JOIN ox_groups g ON (a.owner IS NULL AND g.name = a.group)
        WHERE ai.toAccount = ?
        ORDER BY ai.id DESC
        LIMIT 5
    ]]

    local invoices = MySQL.rawExecute.await(invoicesQuery,{account.accountId})
    
    local balance = tonumber(account:getMeta('balance'))

    return {
        balance = balance,
        overview = overview,
        transactions = transactions,
        invoices = invoices,
    }
end)

local function sanitizeSearch(search)
    local str = {}

    -- Split the search string by whitespace and iterate over each word
    for word in search:gmatch("%S+") do
        table.insert(str, "+")
        -- Remove punctuation and control characters from the word
        local sanitized_word = word:gsub("[%p%c]", "")
        table.insert(str, sanitized_word)
        table.insert(str, "*")
    end

    -- Remove the third element if there are more than 3 items in the list
    if #str > 3 then
        table.remove(str, 3)
    end

    -- Join the table into a string
    search = table.concat(str)

    -- Return nil if the result is "+*", otherwise return the sanitized search
    return search == "+*" and nil or search
end

---@param data {accountId, page, search}
lib.callback.register('ox_banking:getAccountUsers',function(source, data)
    local account = OxAccount.get(data.accountId);
    local hasPermission = account:playerHasPermission(source, 'manageUser')

    if not hasPermission then return end

    local wildcard = sanitizeSearch(data.search)
    local searchStr = ''

    local accountGroup = account:getMeta('group')

    local queryParams = {data.accountId}

    if wildcard then
        searchStr = searchStr.."AND MATCH(c.fullName) AGAINST (? IN BOOLEAN MODE)"
        table.insert(queryParams, wildcard)
    end

    if (accountGroup) then
        local params = {accountGroup}

        local usersQuery = [[
            SELECT c.citizenid, c.fullName AS name, gg.accountRole AS role FROM player_groups cg
            LEFT JOIN accounts a ON cg.group = a.group
            LEFT JOIN players c ON c.citizenid = cg.citizenid
            LEFT JOIN ox_group_grades gg ON (cg.name = gg.group AND cg.grade = gg.grade)
            WHERE cg.group = ? ]] .. searchStr.. [[
            ORDER BY role DESC
            LIMIT 12
            OFFSET ?
        ]]

        local countQuery = [[
            SELECT COUNT(*) FROM player_groups cg
            LEFT JOIN accounts a ON cg.group = a.group
            LEFT JOIN players c ON c.citizenid = cg.citizenid
            LEFT JOIN ox_group_grades gg ON (cg.group = gg.group AND cg.grade = gg.grade)
            WHERE cg.group = ?
        ]]

        local count = MySQL.prepare.await(countQuery, params)

        if wildcard then table.insert(params, wildcard) end
        table.insert(params, data.page * 12)

        local users = MySQL.rawExecute.await(usersQuery, params)

        return {
            numberOfPages = count,
            users = users,
        }
    end

    local usersCount = MySQL.prepare.await('SELECT COUNT(*) FROM `accounts_access` aa LEFT JOIN players c ON c.citizenid = aa.charId WHERE accountId = ? '.. searchStr,
        queryParams
    )

    table.insert(queryParams, data.page * 12)

    local users = {}

    if usersCount then
        local userQuery = [[
            SELECT c.citizenid, a.role, c.fullName AS name FROM accounts_access a
            LEFT JOIN players c ON c.citizenid = a.charId
            WHERE a.accountId = ? ]] ..searchStr.. [[
            ORDER BY a.role DESC
            LIMIT 12
            OFFSET ?
        ]]
        users = MySQL.rawExecute.await(userQuery ,queryParams)
    end

    return {
      numberOfPages = math.ceil(usersCount / 12) or 1,
      users = users,
    }
end)

---@param data {accountId, stateId, role}
lib.callback.register('ox_banking:addUserToAccount', function(source, data) 
    local account = OxAccount.get(data.accountId)
    local hasPermission = account:playerHasPermission(source, 'addUser')

    if not hasPermission then return false end

    local currentRole = account:getCharacterRole(data.stateId)

    if currentRole then return { success = false, message = 'invalid_input' } end

    return account:setCharacterRole(data.stateId, data.role) or { success = false, message = 'state_id_not_exists' }
end)

---@param data {accountId, targetStateId, values}
lib.callback.register('ox_banking:manageUser', function(source, data) 
    local account = OxAccount.get(data.accountId)
    local hasPermission = account:playerHasPermission(source, 'manageUser')

    if not hasPermission then return false end

    return account:setCharacterRole(data.targetStateId, data.values.role)
end)

---@param data {accountId, targetStateId}
lib.callback.register('ox_banking:removeUser', function(source, data) 
    local account = OxAccount.get(data.accountId)
    local hasPermission = account:playerHasPermission(source, 'removeUser')

    if not hasPermission then return false end

    return account:setCharacterRole(data.targetStateId, nil)
end)

---@param data {accountId, targetStateId}
lib.callback.register('ox_banking:transferOwnership', function(source, data) 
    local account = OxAccount.get(data.accountId)
    local hasPermission = account:playerHasPermission(source, 'transferOwnership')

    if not hasPermission then return {success = false, message = 'no_permission'} end

    local targetCharId = MySQL.prepare.await('SELECT `citizenid` FROM `players` WHERE `citizenid` = ?', {data.targetStateId})

    if not targetCharId then
        return {
            success =false,
            message = 'state_id_not_exists',
        }
    end

    local accountOwner = account:getMeta('owner')

    if accountOwner == targetCharId then
        return {
            success =  false,
            message = 'invalid_input',
        }
    end

    local charId = GetPlayerCID(source)

    MySQL.prepare.await("INSERT INTO `accounts_access` (`accountId`, `charId`, `role`) VALUES (?, ?, 'owner') ON DUPLICATE KEY UPDATE `role` = 'owner'",
        {data.accountId, targetCharId}
    )

    MySQL.prepare.await('UPDATE `accounts` SET `owner` = ? WHERE `id` = ?', {targetCharId, data.accountId})
    MySQL.prepare.await("UPDATE `accounts_access` SET `role` = 'manager' WHERE `accountId` = ? AND `charId` = ?", {
        data.accountId, charId,
    })

    return {success = true}
end)

---@param data {accountId, name}
lib.callback.register('ox_banking:renameAccount', function(source, data) 
    local account = OxAccount.get(data.accountId)
    local hasPermission = account:playerHasPermission(source, 'manageAccount')

    if not hasPermission then return false end

    MySQL.prepare.await('UPDATE `accounts` SET `label` = ? WHERE `id` = ?', {data.name, data.accountId})

    return true
end)

---@param data {accountId}
lib.callback.register('ox_banking:convertAccountToShared', function(source, data) 
    local charId = GetPlayerCID(source)

    if not charId then return end

    local account = OxAccount.get(data.accountId)

    if not account then return end

    local data = account:getMeta({'type', 'owner'})


    if data.type ~= 'personal' or data.owner ~= charId  then return false end

    return account:setShared()
end)

---@param data { accountId, filters }
lib.callback.register('ox_banking:getLogs', function(playerId, data)
    local account = OxAccount.get(data.accountId)

    local hasPermission = account:playerHasPermission(source, 'viewHistory')

    if not hasPermission then return false end

    local search = sanitizeSearch(data.filters.search)

    local dateSearchString = '';
    local queryParams = {data.accountId, data.accountId, data.accountId, data.accountId, data.accountId, data.accountId, data.accountId, data.accountId}

    local typeQueryString = ''

    local queryWhere = "WHERE (at.fromId = ? OR at.toId = ?)"

    if #search > 0 then
        queryWhere = queryWhere..[[
             AND (MATCH(c.fullName) AGAINST (? IN BOOLEAN MODE) OR MATCH(at.message) AGAINST (? IN BOOLEAN MODE)) 
        ]]
        table.insert(queryParams, search)
        table.insert(queryParams, search)
    end

    if data.filters.type and data.filters.type ~= 'combined' then
        typeQueryString = typeQueryString.."AND ("
        if data.filters.type == 'outbound' then
            typeQueryString = typeQueryString.."at.fromId = ?)"
        else 
            typeQueryString = typeQueryString.."at.toId = ?)"
        end

        table.insert(queryParams, data.accountId)
    end

    if data.filters.date then
        local date = exports.ox_banking:getFormattedDates(data.filters.date)

        dateSearchString = "AND (DATE(at.date) BETWEEN ? AND ?)"
        table.insert(queryParams, date.from)
        table.insert(queryParams, date.to)
    end

    queryWhere = queryWhere .. typeQueryString .. dateSearchString

    local countQueryParams = {}
    for i = 3, #queryParams do  -- Lua indexing starts at 1, so slice from the 3rd element
        table.insert(countQueryParams, queryParams[i])
    end

    table.insert(queryParams, data.filters.page * 6)

    local queryQuery = [[
        SELECT
            at.id,
            at.fromId,
            at.toId,
            at.message,
            at.amount,
            CONCAT(fa.id, ' - ', IFNULL(cf.fullName, ogf.label)) AS fromAccountLabel,
            CONCAT(ta.id, ' - ', IFNULL(cf.fullName, ogt.label)) AS toAccountLabel,
            UNIX_TIMESTAMP(at.date) AS date,
            c.fullName AS name,
            CASE
              WHEN at.toId = ? THEN 'inbound'
              ELSE 'outbound'
            END AS 'type',
            CASE
                WHEN at.toId = ? THEN at.toBalance
                ELSE at.fromBalance
            END AS newBalance
          FROM accounts_transactions at
          LEFT JOIN players c ON c.citizenid = at.actorId
          LEFT JOIN accounts ta ON ta.id = at.toId
          LEFT JOIN accounts fa ON fa.id = at.fromId
          LEFT JOIN players ct ON (ta.owner IS NOT NULL AND at.fromId = ? AND ct.citizenid = ta.owner)
          LEFT JOIN players cf ON (fa.owner IS NOT NULL AND at.toId = ? AND cf.citizenid = fa.owner)
          LEFT JOIN ox_groups ogt ON (ta.owner IS NULL AND at.fromId = ? AND ogt.name = ta.group)
          LEFT JOIN ox_groups ogf ON (fa.owner IS NULL AND at.toId = ? AND ogf.name = fa.group) ]]..queryWhere..[[
          ORDER BY at.id DESC
          LIMIT 6
          OFFSET ?
    ]]

    local queryData = MySQL.rawExecute.await(queryQuery, queryParams)

    local queryLogsCount = [[
        SELECT COUNT(*)
          FROM accounts_transactions at
          LEFT JOIN players c ON c.citizenid = at.actorId
          LEFT JOIN accounts ta ON ta.id = at.toId
          LEFT JOIN accounts fa ON fa.id = at.fromId
          LEFT JOIN players ct ON (ta.owner IS NOT NULL AND at.fromId = ? AND ct.citizenid = ta.owner)
          LEFT JOIN players cf ON (fa.owner IS NOT NULL AND at.toId = ? AND cf.citizenid = fa.owner)
          LEFT JOIN ox_groups ogt ON (ta.owner IS NULL AND at.fromId = ? AND ogt.name = ta.group)
          LEFT JOIN ox_groups ogf ON (fa.owner IS NULL AND at.toId = ? AND ogf.name = fa.group)
    ]]..queryWhere

    local totalLogsCount = MySQL.prepare.await(queryLogsCount,countQueryParams)

    return {
      numberOfPages = math.ceil(totalLogsCount / 6),
      logs = queryData
    }
end)

---@param data { accountId, filters }
lib.callback.register('ox_banking:getInvoices', function(playerId, data)
    local account = OxAccount.get(data.accountId)

    local hasPermission = account:playerHasPermission(playerId, 'payInvoice')

    if not hasPermission then return false end

    local search = sanitizeSearch(data.filters.search)

    local queryParams = {}

    local dateSearchString = ''
    local columnSearchString = ''
    local typeSearchString = ''

    local query = ''
    local queryJoins = ''

    if data.filters.type == 'unpaid' then
        typeSearchString = '(ai.toAccount = ? AND ai.paidAt IS NULL)'

        table.insert(queryParams, data.accountId)

        if #search > 0 then
            columnSearchString = ' AND (MATCH(a.label) AGAINST (? IN BOOLEAN MODE) OR MATCH(ai.message) AGAINST (? IN BOOLEAN MODE))'
            table.insert(queryParams, search)
            table.insert(queryParams, search)
        end

        queryJoins = [[
            LEFT JOIN accounts a ON ai.fromAccount = a.id 
            LEFT JOIN players c ON ai.actorId = c.citizenid 
            LEFT JOIN players co ON (a.owner IS NOT NULL AND co.citizenid = a.owner) 
            LEFT JOIN ox_groups g ON (a.owner IS NULL AND g.name = a.group)
        ]]

        query = [[
            SELECT 
                ai.id, 
                c.fullName as sentBy, 
                CONCAT(a.id, ' - ', IFNULL(co.fullName, g.label)) AS label, 
                ai.amount, ai.message, 
                UNIX_TIMESTAMP(ai.sentAt) AS sentAt, 
                UNIX_TIMESTAMP(ai.dueDate) as dueDate, 
                'unpaid' AS type 
            FROM accounts_invoices ai
        ]]..queryJoins
        
        goto OUT
    elseif data.filters.type == 'paid' then
        typeSearchString = '(ai.toAccount = ? AND ai.paidAt IS NOT NULL)'

        table.insert(queryParams, data.accountId)

        if #search > 0 then
            columnSearchString = " AND (MATCH(c.fullName) AGAINST (? IN BOOLEAN MODE) OR MATCH(ai.message) AGAINST (? IN BOOLEAN MODE) OR MATCH(a.label) AGAINST (? IN BOOLEAN MODE))"
            table.insert(queryParams, search)
            table.insert(queryParams, search)
            table.insert(queryParams, search)
        end

        queryJoins = [[ 
            LEFT JOIN accounts a ON ai.fromAccount = a.id 
            LEFT JOIN players c ON ai.payerId = c.citizenid 
            LEFT JOIN players ca ON ai.actorId = ca.citizenid 
            LEFT JOIN players co ON (a.owner IS NOT NULL AND co.citizenid = a.owner)
            LEFT JOIN ox_groups g ON (a.owner IS NULL AND g.name = a.group)
        ]]

        query = [[
            SELECT 
                ai.id, 
                c.fullName as paidBy, 
                ca.fullName as sentBy, 
                CONCAT(a.id, ' - ', IFNULL(co.fullName, g.label)) AS label, 
                ai.amount, ai.message, 
                UNIX_TIMESTAMP(ai.sentAt) AS sentAt, 
                UNIX_TIMESTAMP(ai.dueDate) AS dueDate, 
                UNIX_TIMESTAMP(ai.paidAt) AS paidAt, 
                'paid' AS type 
            FROM accounts_invoices ai
        ]]..queryJoins

        goto OUT
    elseif data.filters.type == 'sent' then
        typeSearchString = '(ai.fromAccount = ?)'

        table.insert(queryParams, data.accountId)

        if #search > 0 then
            columnSearchString = " AND (MATCH(c.fullName) AGAINST (? IN BOOLEAN MODE) OR MATCH (ai.message) AGAINST (? IN BOOLEAN MODE) OR MATCH (a.label) AGAINST (? IN BOOLEAN MODE))"
            table.insert(queryParams, search)
            table.insert(queryParams, search)
            table.insert(queryParams, search)
        end

        queryJoins = [[
            LEFT JOIN accounts a ON ai.toAccount = a.id 
            LEFT JOIN players c ON ai.actorId = c.citizenid 
            LEFT JOIN players co ON (a.owner IS NOT NULL AND co.citizenid = a.owner) 
            LEFT JOIN ox_groups g ON (a.owner IS NULL AND g.name = a.group)
        ]]

        query = [[
            SELECT 
                ai.id, 
                c.fullName as sentBy, 
                CONCAT(a.id, ' - ', IFNULL(co.fullName, g.label)) AS label, 
                ai.amount, ai.message, 
                UNIX_TIMESTAMP(ai.sentAt) AS sentAt, 
                UNIX_TIMESTAMP(ai.dueDate) AS dueDate, 
            CASE 
                WHEN ai.payerId IS NOT NULL THEN 'paid' 
                WHEN NOW() > ai.dueDate THEN 'overdue' 
                ELSE 'sent' 
            END AS status, 
            'sent' AS type 
            FROM accounts_invoices ai
        ]]..queryJoins

        goto OUT
    end

    ::OUT::

    if data.filters.date then
        local date = exports.ox_banking:getFormattedDates(data.filters.date)
        local dateCol
        if data.filters.type == "unpaid" then
            dateCol = "ai.dueDate"
        elseif data.filters.type == "paid" then
            dateCol = "ai.paidAt"
        else
            dateCol = "ai.sentAt"
        end

        dateSearchString = 'AND (DATE('..dateCol..') BETWEEN ? AND ?)'
        table.insert(queryParams, date.from, date.to)
    end

    local whereStatement = 'WHERE '..typeSearchString .. columnSearchString .. dateSearchString

    table.insert(queryParams, data.filters.page * 6)

    local result = MySQL.rawExecute.await(query..whereStatement..' ORDER BY ai.id DESC LIMIT 6 OFFSET ?',
        queryParams
    )

    table.remove(queryParams, #queryParams)

    local totalInvoices = MySQL.prepare.await('SELECT COUNT(*) FROM accounts_invoices ai '..queryJoins..whereStatement, 
        queryParams
    )

    local numberOfPages = math.ceil(totalInvoices / 6)

    return {
      invoices = result,
      numberOfPages = numberOfPages,
    }
end)

---@param data { data.invoiceId }
lib.callback.register('ox_banking:payInvoice', function(source, data)
  local charId = GetPlayerCID(source)

  if not charId then return end

  return PayAccountInvoice(data.invoiceId, charId)
end)

--[[
   ____    ____     ____   __   __
  / __ \  |  _ \   / __ \  \ \ / /
 | |  | | | |_) | | |  | |  \ V / 
 | |  | | |  _ <  | |  | |   > <  
 | |__| | | |_) | | |__| |  / . \ 
  \___\_\ |____/   \____/  /_/ \_\
                                  
]]

local UPSERT_GROUP = [[
    INSERT INTO ox_groups (`name`, `label`, `type`, `hasAccount`)
    VALUES (?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
        `name` = VALUES(`name`),
        `label` = VALUES(`label`),
        `type` = VALUES(`type`),
        `hasAccount` = VALUES(`hasAccount`)
    ]]
local UPSERT_GRADE = [[
    INSERT INTO ox_group_grades (`group`, `grade`, `label`, `accountRole`) 
    VALUES (?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
        `group` = VALUES(`group`), 
        `grade` = VALUES(`grade`), 
        `label` = VALUES(`label`), 
        `accountRole` = VALUES(`accountRole`)
    ]]

local function safeQuery(...)
    local ok, resp = pcall(...)

    if not ok then
        return warn(resp)
    end

    return resp
end

Citizen.CreateThreadNow(function()
    local jobs = exports.qbx_core:GetJobs()
    local gangs = exports.qbx_core:GetGangs()

    local queries = {}
    local ox_group_grades_queries = {}

    local success1, result1 = pcall(MySQL.scalar.await, 'SELECT 1 FROM ox_groups')
    local success2, result2 = pcall(MySQL.scalar.await, 'SELECT 1 FROM ox_group_grades')

    if not success1 or not success2 then return end

    for groupName, groupData in pairs(jobs) do
        if groupName == 'unemployed' then goto SKIP end

        local group_query = { query = UPSERT_GROUP, values = {groupName, groupData.label, groupData.type or nil, groupData.hasAccount and '1' or '0'} }

        table.insert(queries, group_query)

        for grade, gradeData in pairs(groupData.grades) do
            local grade_query = { query = UPSERT_GRADE, values = {groupName, tostring(grade), gradeData.name, gradeData.bankAuth or nil} }
            table.insert(queries, grade_query)
        end

        ::SKIP::
    end

    for groupName, groupData in pairs(jobs) do
        if groupName == 'none' then goto SKIP end

        local group_query = { query = UPSERT_GROUP, values = {groupName, groupData.label, groupData.type or nil, groupData.hasAccount and '1' or '0'} }

        table.insert(queries, group_query)

        for grade, gradeData in pairs(groupData.grades) do
            local grade_query = { query = UPSERT_GRADE, values = {groupName, tostring(grade), gradeData.name, gradeData.bankAuth or nil} }
            table.insert(queries, grade_query)
        end

        ::SKIP::
    end
    
    local resp = safeQuery(MySQL.transaction.await, queries)

    lib.waitFor(function()
        if resp then return true end
    end, nil, false)

    assert(resp, 'Failed to Add Groups in ox_groups')

    for groupName, groupData in pairs(jobs) do
        if groupData.hasAccount then
            local result = MySQL.scalar.await('SELECT id FROM accounts WHERE `group` = ?', {groupName})

            if not result then
                -- Create a group specific default account
                exports.ox_banking:CreateAccount(groupName, groupData.label, true)
            end
        end
    end
end)
------------------------------------

lib.callback.register('ox_banking:fetchAccountsForSendInvoice', function(source)
    local source = source

    local accounts = {}

    local citizenid = GetPlayerCID(source)

    if not citizenid then 
        return nil 
    end

    local response = MySQL.query.await('SELECT `accountId` FROM accounts_access WHERE `charId` = ?', {citizenid})

    if not response then 
        return nil
    end

    for i=1, #response do
        local accountId = response[i].accountId

        local account = OxAccount.get(accountId)

        if not account then return end

        local hasPermission = account:playerHasPermission(source, 'sendInvoice')

        if not hasPermission then goto continue end

        accounts[#accounts + 1] = {label = account:getMeta('label') or "Account", value = account:getMeta('id')}

        ::continue::
    end
    return accounts
end)

lib.callback.register('ox_banking:createInvoice', function(source, data)
    local citizenid = GetPlayerCID(source)

    if not citizenid then 
        return {success = false, message = 'Invalid Executor'}
    end

    local fromAccount = data.fromAccount
    local toAccount = data.toAccount
    local amount = data.amount
    local message = data.message
    local dueDate = data.dueDate
    local receiver = data.receiver

    if not fromAccount or not toAccount or not amount or not message or not dueDate then return {success = false, message = 'Incomplete Details Sent.'} end

    local senderAccount = OxAccount.get(fromAccount)

    if not senderAccount then return {success = false, message = 'Invalid Sender Account.'} end

    local hasPermission = senderAccount:playerHasPermission(source, 'sendInvoice')

    if not hasPermission then return {success = false, message = 'No Permission to Send Invoice From This Account.'} end

    local receiverAccount = OxAccount.get(toAccount)
    
    if not receiverAccount then return {success = false, message = 'Invalid Receiver Account.'} end

    local validReceiver = receiverAccount:getCharacterRole(receiver)

    if not validReceiver then return {success = false, message = 'Receiver not have access to bank account.'} end

    if amount < 1 then return {success = false, message = 'Invalid Amount'} end

    message = '['..receiver..'] '..message

    local response = senderAccount:createInvoice({
        actorId = citizenid,
        toAccount = toAccount,
        amount = tonumber(amount),
        message = message,
        dueDate = dueDate
    })

    return response
end)

lib.addCommand('invoice', {
    help = 'Send Invoice to an account.',
}, function(source, args, raw)
    TriggerClientEvent("ox_banking:openInvoiceDialog", source)
end)

------- DEBUG---------------------

RegisterCommand('createAccount', function(source, args)
    local charId = GetPlayerCID(source)

    if not charId then return end

    local label = args[1]

    exports.ox_banking:CreateAccount(charId, label)
end)

RegisterCommand('bank:debug', function(source, args)
    local source = source

    local accounts = {}

    local citizenid = GetPlayerCID(source)

    if not citizenid then 
        return nil 
    end

    local response = MySQL.query.await('SELECT `accountId` FROM accounts_access WHERE `charId` = ?', {citizenid})

    if not response then 
        return nil
    end

    for i=1, #response do
        local accountId = response[i].accountId

        local account = OxAccount.get(accountId)

        if not account then return end

        local hasPermission = account:playerHasPermission(source, 'sendInvoice')

        if not hasPermission then goto continue end

        accounts[#accounts + 1] = account:getMeta('id')

        ::continue::
    end
    return accounts
end)