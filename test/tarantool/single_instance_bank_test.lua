-- https://github.com/tarantool/jepsen.tarantool/blob/master/resources/tarantool/jepsen.lua
-- TODO: fault injections,
-- https://github.com/tarantool/tarantool/blob/master/test/fuzz/lua/test_engine.lua

local molly = require('molly')
local runner = molly.runner
local client = molly.client
local tests = molly.tests
local log = require('log')
local fio = require('fio')
local math = require('math')

local TEST_DIR = fio.abspath('./tarantool_test_dir')

local SPACE_NAME = 'bank_space'
local ACCOUNTS = 10
local TOTAL_AMOUNT = 100
local MAX_TRANSFER = 2

local function do_withdraw(table, from, to, amount)
    local space = box.space[table]
    box.begin()
    -- local b1 = space:get(from).balance - amount
    -- local b2 = space:get(to).balance + amount
    -- if b1 < 0 or b2 < 0 then
    --     error('Negative balance')
    -- end
    space:update(from, {{'-', 'balance', amount}})
    space:update(to, {{'+', 'balance', amount}})
    box.commit()
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

-- WARNING: Cleanup and running box.cfg() should be executed in
-- the setup method.
if fio.path.exists(TEST_DIR) then
    cleanup_dir(TEST_DIR)
else
    fio.mkdir(TEST_DIR)
end

local box_cfg_options = {
    -- memtx_memory = 1024 * 1024,
    -- memtx_use_mvcc_engine = false,
    work_dir = TEST_DIR,
    log_level = 'verbose',
    read_only = false,
}
if type(box.cfg) ~= 'table' then
    box.cfg(box_cfg_options)
end

local cl = client.new()

cl.open = function(self, _addr)
    rawset(self, 'conn', box)
    return true
end

local function assert_ping(conn)
    assert(conn)
    -- if conn:ping({timeout = 2}) ~= true then
    --     error(string.format('No connection to %s', addr))
    -- end
end

cl.setup = function(self)
    assert_ping(self.conn)
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

cl.invoke = function(self, op)
    assert_ping(self.conn)
    log.info(op)
    local state = false
    local v = op.v
    if op.f == 'transfer' then
        local from = v.from
        local to = v.to
        local amount = v.amount
        do_withdraw(SPACE_NAME, from, to, amount)
    elseif op.f == 'read' then
        local space = self.conn.space[SPACE_NAME]
        v = space:select(nil, {timeout = 5, limit = ACCOUNTS})
        if v ~= nil then
            v = v.value
            state = true
        end
    else
        error(string.format('Unknown operation (%s)', op.f))
    end

    return {
        v = v,
        f = op.f,
        process = op.process,
        time = op.time,
        state = state,
    }
end

cl.teardown = function(self)
    assert_ping(self.conn)
    return true
end

cl.close = function(self)
    -- if self.conn and self.conn:ping() == true then
    --     self.conn:close()
    -- end
    return true
end

local test_options = {
    create_reports = true,
    threads = 10,
    nodes = {
        '127.0.0.1:3301',
    },
}

local ok, err = runner.run_test({
    client = cl,
    create_reports = true,
    generator = tests.bank_gen({
        accounts = ACCOUNTS,
        total_amount = TOTAL_AMOUNT,
        max_transfer = MAX_TRANSFER,
	}):take(10^4),
}, test_options)

assert(ok == true)
assert(err == nil)

os.exit(0)
