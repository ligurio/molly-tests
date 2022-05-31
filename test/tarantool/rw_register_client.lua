-- Molly client with read and write operations for memcached.

local dev_checks = require('checks')
local math = require('math')
local net_box = require('net.box')
local molly = require('molly')

local function r()
    return {
        f = 'read',
        v = nil,
    }
end

local function w()
    return {
        f = 'write',
        v = math.random(1, 100),
    }
end

local space_name = 'rw_register_mc'

local client = molly.client.new()

client.open = function(self, addr)
    dev_checks('table', 'string')

    rawset(self, 'addr', addr)
    local conn = net_box.connect(addr)
    if conn:ping() ~= true then
        error(string.format('No connection to %s', self.addr))
    end
    rawset(self, 'conn', conn)

    return true
end

client.invoke = function(self, op)
    dev_checks('table', {
        f = 'string',
        v = '?',
        process = '?number',
        time = '?number',
    })

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

client.close = function(self)
    return true
end

return {
    client = client,
    ops = {
       r = r,
       w = w,
    }
}
