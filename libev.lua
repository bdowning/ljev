require 'cdef.preprocessed_c'
local ffi = require 'ffi'
local C = ffi.C
local ev = ffi.load('ev')

local loop = ev.ev_default_loop(0)
print(loop)

local libev_lua_cbs = { }

local function lua_cb_trampoline(loop, w, revents)
    libev_lua_cbs[tonumber(ffi.cast('intptr_t', w.data))](loop, w, revents)
    -- print('lua_cb_trampoline', loop, w, revents)
end
local lua_cb_trampoline_cptr =
    ffi.cast('void (*)(struct ev_loop *loop, ev_watcher *w, int revents)',
             lua_cb_trampoline)
print(lua_cb_trampoline, lua_cb_trampoline_cptr)

local function invoke_pending(loop)
    loop.pendingpri = C.NUMPRI

    while loop.pendingpri ~= 0 do
        loop.pendingpri = loop.pendingpri - 1
        while loop.pendingcnt[loop.pendingpri] ~= 0 do
            loop.pendingcnt[loop.pendingpri] =
                loop.pendingcnt[loop.pendingpri] - 1
            local p = loop.pendings[loop.pendingpri]
                + loop.pendingcnt[loop.pendingpri]

            p.w.pending = 0
            if p.w.cb == lua_cb_trampoline_cptr then
                lua_cb_trampoline(loop, p.w, p.events)
            else
                p.w.cb(loop, p.w, p.events)
            end
        end
    end
end
local invoke_pending_cptr = ffi.cast('ev_loop_callback', invoke_pending)

ev.ev_set_invoke_pending_cb(loop, invoke_pending_cptr)-- loop.invoke_cb = invoke_pending_cptr

local count = 0
local function cb(loop, w, revents)
    local div_cnt = count / 1000000
    if math.floor(div_cnt) == div_cnt then
        io.stdout:write(tostring(count), '\n')
    end
    if count == 200000000 then
        ev.ev_break(loop, C.EVBREAK_ALL)
    end
    count = count + 1
end

local ts = { }
for i = 1, 2000 do
    local timer = ffi.new('ev_timer')
    timer.at = 0.002
    timer['repeat'] = 0.002
    timer.cb = lua_cb_trampoline_cptr
    local n = #libev_lua_cbs + 1
    libev_lua_cbs[n] = cb
    timer.data = ffi.cast('void *', n)
    ev.ev_timer_start(loop, timer)
    ts[i] = timer
end

ev.ev_run(loop, 0)
