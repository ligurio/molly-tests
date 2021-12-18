#!/usr/bin/env tarantool

local workdir = os.getenv('TARANTOOL_WORKDIR')
local listen = os.getenv('TARANTOOL_LISTEN')

box.cfg({
    feedback_enabled = false,
    custom_proc_title = 'jepsen',
    listen = listen,
    log_level = 6,
    memtx_memory = 1024*1024*1024,
    net_msg_max = 2 * 1024,
    work_dir = workdir,
    iproto_threads = 2,
})

--[[
if replication == true then
    box.cfg.election_mode = 'candidate'
    box.cfg.election_timeout = 0.5
    box.cfg.memtx_use_mvcc_engine = true
    box.cfg.replication_synchro_quorum = %TARANTOOL_QUORUM%
    box.cfg.replication_synchro_timeout = 0.2
    box.cfg.replication = { %TARANTOOL_REPLICATION% }
    box.cfg.replication_timeout = 1
end
]]

local function bootstrap()
    local space = box.schema.space.create('register_space')
    space:format({
	{ name = 'id', type = 'number' },
	{ name = 'value', type = 'number' },
    })
    space:create_index('pk', {type = 'HASH'})

    space = box.schema.space.create('bank_space')
    space:format({
	{ name = 'id', type = 'number' },
	{ name = 'balance', type = 'number' },
    })
    space:create_index('pk', {type = 'HASH'})

    box.schema.user.grant('guest', 'create,read,write,execute,drop', 'universe')
    box.schema.user.grant('guest', 'read,write', 'space', '_index')
    box.schema.user.grant('guest', 'write', 'space', '_schema')
    box.schema.user.grant('guest', 'write', 'space', '_space')
end

box.once('ljepsen', bootstrap)

-- Function implements a CAS (Compare And Set) operation, which takes a key,
-- old value, and new value and sets the key to the new value if and only if
-- the old value matches what's currently there, and returns a status of
-- operation and old value in case of fail and a new value in case of success.
function cas(space_name, tuple_id, old_value, new_value) -- luacheck: no global
    local space = box.space[space_name]
    box.begin()
    local tuple = space:get{tuple_id}
    if not tuple or tuple.value ~= old_value then
        box.commit()
        return old_value, false
    end
    tuple = space:update(tuple_id, {{'=', 2, new_value}}, {timeout = 0.05})
    box.commit()
    assert(tuple ~= nil)

    return tuple.value, true
end

-- Function returns IP address of a node where current leader of synchronous
-- cluster with enabled Raft consensus protocol is started.
-- Returns nil when Raft is disabled.
function leader_ipaddr() -- luacheck: no global
    local leader_id = box.info.election.leader
    if leader_id == 0 or leader_id == nil then
      return nil
    end
    local leader_upstream = box.info.replication[leader_id].upstream
    if leader_upstream == nil then
      return string.match(box.info.listen, '(.+):[0-9]+')
    end
    local leader_ip_address = string.match(leader_upstream.peer, '[A-z]+@(.+):[0-9]+')

    return leader_ip_address
end

-- Function transfers money between two accounts presented by tuples in a table
-- and returns true in case of success and false in other cases.
function withdraw(space_name, tuple_id_source, tuple_id_dest, amount) -- luacheck: no global
    local space = box.space[space_name]

    box.begin()
    local tuple_source = space:get(tuple_id_source)
    local tuple_dest = space:get(tuple_id_dest)
    local b1 = tuple_source['balance'] - amount
    local b2 = tuple_dest['balance'] + amount
    if b1 < 0 or b2 < 0 then
      box.rollback()
      return false
    end
    space:update(tuple_id_source, {{'-', 'balance', amount}})
    space:update(tuple_id_dest, {{'+', 'balance', amount}})
    box.commit()

    return true
end

-- Function transfers money between two accounts presented by different tables
-- and returns true in case of success and false in other cases.
function withdraw_multitable(space_name_source, space_name_dest, amount) -- luacheck: no global
    local space_source = box.space[space_name_source]
    local space_dest = box.space[space_name_dest]
    local tuple_id = 0

    box.begin()
    local tuple_source = space_source:get(tuple_id)
    local tuple_dest = space_dest:get(tuple_id)
    local bal_source = tuple_source['balance'] - amount
    local bal_dest = tuple_dest['balance'] + amount
    if bal_source < 0 or bal_dest < 0 then
        box.rollback()
        return false
    end
    space_source:update(tuple_id, {{'-', 'balance', amount}})
    space_dest:update(tuple_id, {{'+', 'balance', amount}})
    box.commit()

    return true
end

-- Function implements a UPSERT operation, which takes a key and value and sets
-- the key to the value if key exists or insert new key with that value.
function upsert(conn, space_name, tuple_id, value) -- luacheck: no global
    local space = conn.space[space_name]
    space:upsert({tuple_id, value}, {{'=', 2, value}})

    return true
end
