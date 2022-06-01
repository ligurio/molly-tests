local fio = require('fio')
local net_box = require('net.box')

local molly = require('molly')
local gen = molly.gen
local runner = molly.runner

local cur_dir = fio.pathjoin(fio.dirname(debug.sourcedir()), '?.lua')
package.path = package.path .. ';' .. cur_dir

local helpers = require('helper')

local bank = require('tarantool.bank_client')
local cas_register = require('tarantool.cas_register_client')

local t = require('luatest')
local g = t.group()

local Process = t.Process
local Server = t.Server

local seed = os.time()
math.randomseed(seed)
print(('Random seed: %s'):format(seed))

local datadir = fio.tempdir()

local server = Server:new({
    command = helpers.entrypoint('srv-tarantool'),
    workdir = fio.pathjoin(datadir),
    net_box_port = 3301,
})

g.before_each(function()
    fio.rmtree(datadir)
    fio.mktree(server.workdir)
    server:start()
    local pid = server.process.pid
    t.helpers.retrying(
        {
            timeout = 1,
        },
        function()
            t.assert(Process.is_pid_alive(pid))
            local conn = net_box.connect('127.0.0.1:3301')
            t.assert(conn:is_connected() == true)
            t.assert(conn:ping() == true)
        end
    )
end)

g.after_each(function()
    if server.process then
        server:stop()
    end
    fio.rmtree(datadir)
end)

g.test_bank = function()
    local read = bank.ops.read
    local transfer = bank.ops.transfer
    local test_options = {
        threads = 5,
        nodes = {
            '127.0.0.1:3301',
        },
    }
    local ok, err = runner.run_test({
        client = bank.client,
        generator = gen.cycle(gen.iter({ read(), transfer() })):take(10^3),
    }, test_options)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
end

g.test_cas_register = function()
    local r = cas_register.ops.r
    local w = cas_register.ops.w
    local cas = cas_register.ops.cas
    local test_options = {
        threads = 5,
        nodes = {
            '127.0.0.1:3301',
        },
    }
    local ok, err = runner.run_test({
        client = cas_register.client,
        generator = gen.cycle(gen.iter({ r, w, cas, })):take(1000),
    }, test_options)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
end
