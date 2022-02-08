-- ljepsen client with read and transfer operations for bank test.

local checks = require('checks')
local math = require('math')
local net_box = require('net.box')

local ljepsen = require('ljepsen')

local client = ljepsen.client
local space_name = 'bank_space'
local accounts = 10
local total_amount = 100

local function read()
    return {
        f = 'read',
        v = nil,
    }
end

local function transfer()
    return {
        f = 'transfer',
        v = {
            from = math.random(1, accounts),
            to = math.random(1, accounts),
            amount = math.random(1, total_amount),
        }
    }
end

local cl = client.new()

cl.open = function(self, addr)
    checks('table', 'string')

    rawset(self, 'addr', addr)
    local conn = net_box.connect(self.addr)
    if conn:ping() ~= true then
        error(string.format('No connection to %s', self.addr))
    end
    assert(conn:wait_connected(0.5) == true)
    assert(conn:is_connected() == true)
    rawset(self, 'conn', conn)

    return true
end

cl.setup = function(self)
    checks('table')

    if self.conn:ping() ~= true then
        error(string.format('No connection to %s', self.addr))
    end

    local space = self.conn.space[space_name]
    assert(space ~= nil)
    print('Populating account')
    for a = 1, accounts do
        local sum = math.random(1, 100)
        total_amount = total_amount - sum
        space:insert({a, sum})
    end

    return true
end

cl.invoke = function(self, op)
    checks('table', {
        f = 'string',
        v = '?',
        process = '?number',
        time = '?number',
    })

    if self.conn:ping() ~= true then
        error(string.format('No connection to %s', self.addr))
    end

    local space = self.conn.space[space_name]
    local state = false
    local v = op.v
    if op.f == 'transfer' then
        local from = v.from
        local to = v.to
        local amount = v.amount
        state = self.conn:call('withdraw', {
            space_name,
            from,
            to,
            amount
        })
    elseif op.f == 'read' then
        -- FIXME
        v = space:get(1, {timeout = 0.05})
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
    checks('table')

    if self.conn:ping() ~= true then
        error(string.format('No connection to %s', self.addr))
    end

    return true
end

cl.close = function(self)
    checks('table')

    if self.conn:ping() == true then
        self.conn:close()
    end

    return true
end

return {
    client = cl,
    ops = {
       read = read,
       transfer = transfer,
    }
}
