local t = require('luatest')
local log = require('log')
local Cluster =  require('test.test-helpers.cluster')
local server = require('test.test-helpers.server')
local json = require('json')

local molly = require('molly')
local gen = molly.gen
local runner = molly.runner

local pg = t.group('quorum_master', {
    { engine = 'memtx' },
    { engine = 'vinyl' }
})

pg.before_each(function(cg)
    local engine = cg.params.engine
    cg.cluster = Cluster:new({})
    cg.box_cfg = {
        replication = {
            server.build_instance_uri('master_quorum1');
            server.build_instance_uri('master_quorum2');
            server.build_instance_uri('master_quorum3');
        };
        election_timeout = 0.5,
        memtx_use_mvcc_engine = true,
        replication_connect_quorum = 0;
        replication_synchro_timeout = 0.2,
        replication_timeout = 0.1;
    }

    cg.master_quorum1 = cg.cluster:build_server(
        {
            alias = 'master_quorum1',
            engine = engine,
            box_cfg = cg.box_cfg,
    })

    cg.master_quorum2 = cg.cluster:build_server(
        {
            alias = 'master_quorum2',
            engine = engine,
            box_cfg = cg.box_cfg,
    })

    cg.master_quorum3 = cg.cluster:build_server(
        {
            alias = 'master_quorum3',
            engine = engine,
            box_cfg = cg.box_cfg,
    })


    pcall(log.cfg, {level = 6})

end)

pg.after_each(function(cg)
    cg.cluster.servers = nil
    cg.cluster:drop()
end)

pg.before_each(function(cg)
    cg.cluster:add_server(cg.master_quorum1)
    cg.cluster:add_server(cg.master_quorum2)
    cg.cluster:add_server(cg.master_quorum3)
    cg.cluster:start()
    local bootstrap_function = function()
        box.schema.space.create('test', {
            engine = os.getenv('TARANTOOL_ENGINE')
        })
        box.space.test:create_index('primary')
    end
    cg.cluster:exec_on_leader(bootstrap_function)

end)

pg.after_each(function(cg)
    cg.cluster:drop({
        cg.master_quorum1,
        cg.master_quorum2,
        cg.master_quorum3,
    })
end)

pg.test_qsync_basic = function(cg)
    local repl = json.encode({replication = cg.box_cfg.replication})
    cg.master_quorum1:eval('box.cfg{replication = ""}')
    t.assert_equals(cg.master_quorum1:eval('return box.space.test:insert{1}'), {1})
    cg.master_quorum1:eval(('box.cfg{replication = %s}'):format(repl.replication))
    cg.master_quorum2:wait_vclock_of(cg.master_quorum1)
    t.assert_equals(cg.master_quorum2:eval('return box.space.test:select({}, {limit = 100})'), {{1}})
end

pg.test_qsync_bank = function(cg)
    local repl = json.encode({replication = cg.box_cfg.replication})
    cg.master_quorum1:eval('box.cfg{replication = ""}')
    t.assert_equals(cg.master_quorum1:eval('return box.space.test:insert{1}'), {1})
    cg.master_quorum1:eval(('box.cfg{replication = %s}'):format(repl.replication))
    cg.master_quorum2:wait_vclock_of(cg.master_quorum1)
    t.assert_equals(cg.master_quorum2:eval('return box.space.test:select({}, {limit = 100})'), {{1}})

    local bank = require('test.tarantool.bank_client')
    local read = bank.ops.read
    local transfer = bank.ops.transfer
    local test_options = {
        create_reports = true,
        threads = 5,
        nodes = {
            '127.0.0.1:3301', -- FIXME: should contain Tarantool's IP addresses.
        },
    }
    local ok, err = runner.run_test({
        client = bank.client,
        generator = gen.cycle(gen.iter({ read(), transfer() })):take(10^3),
    }, test_options)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
end

pg.test_qsync_cas_register = function(_)
    local cas_register = require('test.tarantool.cas_register_client')
    local r = cas_register.ops.r
    local w = cas_register.ops.w
    local cas = cas_register.ops.cas
    local test_options = {
        threads = 5,
        create_reports = true,
        nodes = {
            '127.0.0.1:3301', -- FIXME: should contain Tarantool's IP addresses.
        },
    }
    local ok, err = runner.run_test({
        client = cas_register.client,
        generator = gen.cycle(gen.iter({ r, w, cas, })):take(1000),
    }, test_options)
    t.assert_equals(err, nil)
    t.assert_equals(ok, true)
end
