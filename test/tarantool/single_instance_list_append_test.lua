local fio = require('fio')
local log = require('log')
local molly = require('molly')

local runner = molly.runner
local tests = molly.tests

log.info('Tarantool version:', require('tarantool').version)

local TEST_DIR = fio.abspath('./tarantool_test_dir')
local SPACE_NAME = 'list_append'

local KEY_COUNT= 3
local MIN_TXN_LEN = 1
local MAX_TXN_LEN = 2
local MAX_WRITES_PER_KEY = 5

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

local tarantool_list_append = molly.client.new()

tarantool_list_append.open = function(self, _addr)
    rawset(self, 'conn', box)
    return true
end

local function assert_ping(conn)
    assert(conn)
end

tarantool_list_append.setup = function(self)
    assert_ping(self.conn)
    -- if self.conn.space[SPACE_NAME] then
    --     return
    -- end
    -- local space = self.conn.schema.create_space(SPACE_NAME)
    -- assert(space ~= nil)
    -- space:format({
    --     { 'key', type = 'number' },
    --     { 'list', type = 'array' },
    -- })
    -- space:create_index('pk')

    pcall(self.conn.schema.create_space, SPACE_NAME)
    pcall(self.conn.space[SPACE_NAME].format, self.conn.space[SPACE_NAME], {
        { 'key', type = 'number' },
        { 'list', type = 'array' },
    })
    pcall(self.conn.space[SPACE_NAME].create_index, self.conn.space[SPACE_NAME], 'pk')

    return true
end

local IDX_MOP_TYPE = 1
local IDX_MOP_KEY = 2
local IDX_MOP_VAL = 3

tarantool_list_append.invoke = function(self, op)
    local op_status = 'ok'
    local res = table.copy(op.value)
    local space = self.conn.space[SPACE_NAME]
    for mop_idx, mop in ipairs(op.value) do
        local mop_key = mop[IDX_MOP_KEY]
        local mop_type = mop[IDX_MOP_TYPE]
        if mop_type == 'r' then
            local tuple = space:get(mop_key)
            if tuple then
                res[mop_idx][IDX_MOP_VAL] = tuple[2]
			else
                res[mop_idx][IDX_MOP_VAL] = box.NULL
            end
        elseif mop_type == 'append' then
            local mop_value = mop[IDX_MOP_VAL]
			-- FIXME: https://github.com/tarantool/tarantool/issues/10788.
			-- space:upsert({mop_key, {mop_value}}, {{'!', '[2][1]', mop_value}})
			local tuple = space:get(mop_key)
			local list = {}
			if tuple then
			    list = table.copy(tuple[2])
			end
			table.insert(list, mop_value)
			space:upsert({mop_key, list}, {{'=', 2, list}})
        end
    end

    return {
        value = res,
        f = op.f,
        process = op.process,
        type = op_status,
    }
end

tarantool_list_append.teardown = function(self)
    return true
end

tarantool_list_append.close = function(self)
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
    client = tarantool_list_append,
    create_reports = true,
    generator = tests.list_append_gen({
        key_count = KEY_COUNT,
        min_txn_len = MIN_TXN_LEN,
        max_txn_len = MAX_TXN_LEN,
        max_writes_per_key = MAX_WRITES_PER_KEY,
	}):take(150),
}, test_options)

if err then
    log.info(err)
end

os.exit(ok and 0 or 1)
