-- Molly client with read, write and CAS operations.

local net_box = require('net.box')
local molly = require('molly')

local client = molly.client

local space_name = 'register_space'

local cl = client.new()

cl.open = function(self, addr)
    rawset(self, 'addr', addr)
    local conn = net_box.connect(addr)
    if conn:ping() ~= true then
        error(string.format('No connection to %s', self.addr))
    end
    assert(conn:wait_connected(0.5) == true)
    assert(conn:is_connected() == true)
    rawset(self, 'conn', conn)

    return true
end

cl.setup = function(self)
    if self.conn:ping() ~= true then
        error(string.format('No connection to %s', self.addr))
    end

    return true
end

cl.invoke = function(self, op)
    -- TODO: try async mode in net_box module
    -- https://www.tarantool.io/en/doc/latest/reference/reference_lua/net_box/#lua-function.conn.request
    if self.conn:ping() ~= true then
        error(string.format('No connection to %s', self.addr))
    end

    local tuple_id = 1
    local space = self.conn.space[space_name]
    assert(space ~= nil)
    local tuple_value
    local state
    if op.f == 'write' then
        tuple_value = space:replace({tuple_id, op.v}, {timeout = 0.05})
        tuple_value = tuple_value.value
        state = true
    elseif op.f == 'read' then
        tuple_value = space:get(tuple_id, {timeout = 0.05})
        if tuple_value ~= nil then
            tuple_value = tuple_value.value
        end
        state = true
    elseif op.f == 'cas' then
        local old_value = op.v[1]
        local new_value = op.v[2]
        tuple_value, state = self.conn:call('cas', {
            space_name,
            tuple_id,
            old_value,
            new_value
        }, {
            timeout = 0.5
        })
    else
        error(string.format('Unknown operation (%s)', op.f))
    end

    return {
        v = tuple_value,
        f = op.f,
        process = op.process,
        time = op.time,
        state = state,
    }
end

cl.teardown = function(self)
    if self.conn:ping() ~= true then
        error(string.format('No connection to %s', self.addr))
    end

    return true
end

cl.close = function(self)
    if self.conn:ping() == true then
        self.conn:close()
    end

    return true
end

return {
    client = cl,
}
