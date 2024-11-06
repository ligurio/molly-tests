local fio = require('fio')
local log = require('log')
local molly = require('molly')

log.info('Tarantool version:', require('tarantool').version)

local TEST_DIR = fio.abspath('./tarantool_test_dir')
local SPACE_NAME = 'rw_register'

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

local tarantool_rw_register = molly.client.new()

tarantool_rw_register.open = function(self, _addr)
    rawset(self, 'conn', box)
    return true
end

local function assert_ping(conn)
    assert(conn)
end

tarantool_rw_register.setup = function(self)
    assert_ping(self.conn)
    if self.conn.space[SPACE_NAME] and
       self.conn.space.index ~= nil then
        return true
    end

    -- local space = self.conn.schema.create_space(SPACE_NAME)
    -- space:format({
    --     { 'key', type = 'string' },
    --     { 'value', type = 'number' },
    -- })
    -- space:create_index('pk')

    pcall(self.conn.schema.create_space, SPACE_NAME)
    pcall(self.conn.space[SPACE_NAME].format, self.conn.space[SPACE_NAME], {
        { 'key', type = 'string' },
        { 'value', type = 'number' },
    })
    pcall(self.conn.space[SPACE_NAME].create_index, self.conn.space[SPACE_NAME], 'pk')

    return true
end

local IDX_OP_TYPE = 1
local IDX_OP_KEY = 2
local IDX_OP_VAL = 3

tarantool_rw_register.invoke = function(self, op)
    local space = self.conn.space[SPACE_NAME]
    local op_status = 'ok'
    local value = op.value[1]
    local op_type = value[IDX_OP_TYPE]
    local op_key = value[IDX_OP_KEY]
    local op_val = value[IDX_OP_VAL]
    if op_type == 'r' then
        local tuple = space:get(op_key)
        if tuple then
            op.value[1][IDX_OP_VAL] = tuple[2]
		else
            op.value[1][IDX_OP_VAL] = box.NULL
        end
    elseif op_type == 'w' then
		space:upsert({op_key, op_val}, {{'=', 2, op_val}})
    else
        log.warn('Unknown operation type: %s', op_type)
    end

    return {
        value = op.value,
        f = op.f,
        process = op.process,
        type = op_status,
    }
end

tarantool_rw_register.teardown = function(self)
    return true
end

tarantool_rw_register.close = function(self)
    return true
end

local test_options = {
    create_reports = true,
    threads = 1,
    nodes = {
        '127.0.0.1:3301',
    },
}

local ok, err = molly.runner.run_test({
    client = tarantool_rw_register,
    generator = molly.tests.rw_register_gen(),
}, test_options)

if err then
    log.info(err)
end

os.exit(ok and 0 or 1)
