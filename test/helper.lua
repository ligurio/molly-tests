require('strict').on()

local fio = require('fio')
local digest = require('digest')
local helpers = table.copy(require('test-helpers'))
local t = require('luatest')

t.configure({
    shuffle = 'group'
})

helpers.project_root = fio.dirname(debug.sourcedir())

if os.getenv('DEV') == nil then
    os.setenv('DEV', 'ON')
end

local __fio_tempdir = fio.tempdir
fio.tempdir = function(base)
    base = base or os.getenv('TMPDIR')
    if base == nil or base == '/tmp' then
        return __fio_tempdir()
    else
        local random = digest.urandom(9)
        local suffix = digest.base64_encode(random, {urlsafe = true})
        local path = fio.pathjoin(base, 'tmp.topology.' .. suffix)
        fio.mktree(path)
        return path
    end
end

function helpers.entrypoint(name)
    local path = fio.pathjoin(
        helpers.project_root,
        'test', 'entrypoint',
        string.format('%s.lua', name)
    )
    if not fio.path.exists(path) then
        error(path .. ': no such entrypoint', 2)
    end
    return path
end

function helpers.box_cfg()
    if type(box.cfg) ~= 'function' then
        return
    end

    local tempdir = fio.tempdir()
    box.cfg({
        memtx_dir = tempdir,
        wal_mode = 'none',
    })
    fio.rmtree(tempdir)
end

-- Generate a pseudo-random string
function helpers.gen_string(length)
    local symbols = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    length = length or 10
    local string = ''
    local tbl = {}
    symbols:gsub(".", function(c) table.insert(tbl, c) end)
    for _ = 1, length do
        string = string .. tbl[math.random(1, #tbl)]
    end

    return string
end

-- FIXME: endless waiting
-- luacheck: ignore
local function wait_master(replicaset, master)
    log.info('Waiting until slaves are connected to a master')
    local all_is_ok
    while true do
        all_is_ok = true
        for replica, proc in pairs(replicaset) do
            if replica == master then
                goto continue
            end
	    proc:connect_net_box()
            local info = proc.net_box:eval('return box.info.replication')
            if #info == 0 or #info[1] < 2 then
                all_is_ok = false
                goto continue
            end
            info = info[1]
            for _, replica_info in pairs(info) do
                local upstream = replica_info.upstream
                if upstream and upstream.status ~= 'follow' then
                    all_is_ok = false
                    goto continue
                end
            end
::continue::
        end
        if not all_is_ok then
            fiber.sleep(0.1)
        else
            break
        end
    end
    log.info('Slaves are connected to a master "%s"', master)
end

return helpers
