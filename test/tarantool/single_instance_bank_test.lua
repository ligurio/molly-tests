-- Usage:
--
-- tarantool single_instance_bank_test.lua
-- <snipped>
-- $ ls -1 tarantool_test_dir/history.*
-- tarantool_test_dir/history.json
-- tarantool_test_dir/history.txt
-- java -jar ~/sources/elle-cli/target/elle-cli-0.1.7-standalone.jar --model bank tarantool_test_dir/history.json

local fio = require('fio')
local log = require('log')
local math = require('math')
local molly = require('molly')

local runner = molly.runner
local client = molly.client
local tests = molly.tests

local TEST_DIR = fio.abspath('./tarantool_test_dir')

local SPACE_NAME = 'bank_space'
local ACCOUNTS = 10
local TOTAL_AMOUNT = 100
local MAX_TRANSFER = 10

log.info('Tarantool version: %s', require('tarantool').version)

-- true on successful transfer.
-- false on a failed transfer.
local function transfer(table, from, to, amount)
    local space = box.space[table]
    local balance_from = space:get(from).balance
    if balance_from < amount then
        return false, balance_from - amount
    end
    space:update(from, {{'-', 'balance', amount}})
    space:update(to, {{'+', 'balance', amount}})

    return true
end

local function rmtree(path)
    log.info('CLEANUP %s', path)
    if (fio.path.is_file(path) or fio.path.is_link(path)) then
        fio.unlink(path)
        return
    end
    if fio.path.is_dir(path) then
        for _, p in pairs(fio.listdir(path)) do
            rmtree(fio.pathjoin(path, p))
        end
    end
end

local function cleanup_dir(dir)
    log.info('CLEANUP')
    if dir ~= nil then
        rmtree(dir)
        dir = nil -- luacheck: ignore
    end
end

if fio.path.exists(TEST_DIR) then
    cleanup_dir(TEST_DIR)
else
    fio.mkdir(TEST_DIR)
end

local box_cfg_options = {
    feedback_enabled = false,
    log_level = 'verbose',
    memtx_use_mvcc_engine = true,
    read_only = false,
    work_dir = TEST_DIR,
}

if type(box.cfg) ~= 'table' then
    box.cfg(box_cfg_options)
end

local tarantool_bank_client = client.new()

tarantool_bank_client.open = function(self, _addr)
    rawset(self, 'conn', box)
    return true
end

local function assert_ping(conn)
    assert(conn)
end

tarantool_bank_client.setup = function(self)
    assert_ping(self.conn)
    if self.conn.space[SPACE_NAME] then
        return
    end
    local space = self.conn.schema.create_space(SPACE_NAME)
    assert(space ~= nil)
    space:format({
        { 'account', type = 'number' },
        { 'balance', type = 'number', is_nullable = true },
    })
    space:create_index('pk')
    log.info('Populating accounts')
    local sum = math.floor(TOTAL_AMOUNT / ACCOUNTS)
    local remainder = TOTAL_AMOUNT - sum * ACCOUNTS
    for a = 1, ACCOUNTS do
        local withdraw = a == 1 and sum + remainder or sum
        space:insert({a, withdraw})
        log.info('Put %d RUR on account %d', withdraw, a)
    end
    return true
end

local function balances(accounts)
    local bal = {}
    for _, a in pairs(accounts) do
        local acc_n = tostring(a[1])
        local balance = a[2]
        bal[acc_n] = balance
    end
    return bal
end

-- 8       :ok     :read   {0 83, 1 3, 2 7, 3 15, 4 5, 5 3, 6 10, 7 1}
-- 8       :invoke :transfer       {:from 1, :to 6, :amount 5}
-- 8       :fail   :transfer       [:negative 1 -2]
tarantool_bank_client.invoke = function(self, op)
    assert_ping(self.conn)
    local v = op.value
    local op_type
    if op.f == 'transfer' then
        local from = v.from
        local to = v.to
        local amount = v.amount
        local txn_opts = {
            txn_isolation = 'read-confirmed',
            timeout = 1,
        }
        local ok, res, neg = pcall(box.atomic, txn_opts, transfer,
                                   SPACE_NAME, from, to, amount)
        if not ok then
            error(('transfer operation: %s'):format(res))
        end
        op_type = res and 'ok' or 'fail'
        if res == false then
            v = { 'negative', from, neg }
        end
    elseif op.f == 'read' then
        local space = self.conn.space[SPACE_NAME]
        local accounts = space:select(nil, {timeout = 5, limit = ACCOUNTS})
        if accounts == nil then
            op_type = 'fail'
        else
            v = balances(accounts)
            op_type = 'ok'
        end
    end

    return {
        f = op.f,
        time = op.time,
        process = op.process,
        value = v,
        type = op_type,
    }
end

tarantool_bank_client.teardown = function(self)
    assert_ping(self.conn)
    return true
end

tarantool_bank_client.close = function(self)
    return true
end

local test_options = {
    create_reports = true,
    threads = 1,
    nodes = {
        '127.0.0.1:3301',
    },
}

local ok, err = runner.run_test({
    client = tarantool_bank_client,
    create_reports = true,
    generator = tests.bank_gen({
        accounts = ACCOUNTS,
        max_transfer = MAX_TRANSFER,
	}):take(100),
}, test_options)

if err then
    log.info(err)
end

os.exit(ok and 0 or 1)
