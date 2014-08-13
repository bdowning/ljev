require 'cdef.preprocessed_c'
local bit = require 'bit'
local ffi = require 'ffi'
local C = ffi.C
local evC = ffi.load('ev')

local ev = { }

local active_watchers = {
    { },
    function () error("Inactive Lua libev watcher called!") end
}
local free_watcher_slots = { }
local next_watcher_slot = 3

local function activate_watcher(w, cb)
    local slot = tonumber(ffi.cast('int', w._wC.data)) + 1
    if slot == 1 then
        if #free_watcher_slots > 0 then
            slot = table.remove(free_watcher_slots)
        else
            slot = next_watcher_slot
            next_watcher_slot = next_watcher_slot + 2
        end
        w._wC.data = ffi.cast('void *', slot - 1)
        active_watchers[slot] = w
        -- print('activate_watcher', w, cb, slot)
    end
    active_watchers[slot + 1] = cb
end

local function deactivate_watcher(w)
    local slot = tonumber(ffi.cast('int', w._wC.data)) + 1
    if slot > 1 then
        -- print('deactivate_watcher', w, slot)
        assert(slot > 0)
        w._wC.data = nil
        active_watchers[slot + 1] = nil
        active_watchers[slot] = nil    
        table.insert(free_watcher_slots, slot)
    end
end

local function lua_cb_trampoline(loop, wC, revents)
    -- print('lua_cb_trampoline', loop, wC, revents)
    local slot = tonumber(ffi.cast('int', wC.data)) + 1
    local w = active_watchers[slot]
    active_watchers[slot + 1](loop, w, revents)
    if wC.active == 0 then deactivate_watcher(w) end
end
local lua_cb_trampoline_cptr =
    ffi.cast('void (*)(struct ev_loop *loop, ev_watcher *w, int revents)',
             lua_cb_trampoline)

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

-- ffi.cdef[[void ev_run_guts(struct ev_loop *loop, int flags);]]

-- local function run(loop, flags)
--     loop.loop_depth = loop.loop_depth + 1

--     assert(loop.loop_done ~= C.EVBREAK_RECURSE)

--     loop.loop_done = C.EVBREAK_CANCEL

--     invoke_pending(loop)

--     repeat
--         if loop.curpid ~= 0 then
--             if C.getpid() ~= loop.curpid then
--                 loop.curpid = C.getpid()
--                 loop.postfork = 1
--             end
--         end

--         if loop.postfork ~= 0 then
--             if loop.forkcnt ~= 0 then
--                 evC.queue_events(loop, loop.forks, loop.forkcnt, C.EV_FORK)
--                 invoke_pending(loop)
--             end
--         end

--         if loop.preparecnt ~= 0 then
--             evC.queue_events(loop, loop.prepares, loop.preparecnt, C.EV_FORK)
--             invoke_pending(loop)
--         end

--         if loop.loop_done ~= 0 then
--             break
--         end

--         evC.ev_run_guts(loop, flags)

--         invoke_pending(loop)
--     until not (loop.activecnt ~= 0 and
--                    not loop.loop_done ~= 0 and
--                    not bit.band(flags, C.EVRUN_ONCE + C.EVRUN_NOWAIT) ~= 0)

--     if loop.loop_done == C.EVBREAK_ONE then
--         loop.loop_done = C.EVBREAK_CANCEL
--     end

--     loop.loop_depth = loop.loop_depth - 1

--     return loop.activecnt
-- end

function ev.default_loop(flags)
    return evC.ev_default_loop(flags or 0)
end

ffi.metatype('struct ev_loop', { __index = {
    iteration = function (loop)
        return tonumber(evC.ev_iteration(loop))
    end,

    depth = function (loop)
        return tonumber(evC.ev_depth(loop))
    end,

    now = function (loop)
        return tonumber(evC.ev_now(loop))
    end,

    run = function (loop, flags)
        return evC.ev_run(loop, flags or 0) ~= 0
    end,

    brk = function (loop, how)
        evC.ev_break(loop, how)
    end,

    ref = function (loop) evC.ev_ref(loop) end,
    unref = function (loop) evC.ev_unref(loop) end,

    set_io_collect_interval = function (loop, interval)
        evC.ev_set_io_collect_interval(loop, interval)
    end,

    set_timeout_collect_interval = function (loop, interval)
        evC.ev_set_timeout_collect_interval(loop, interval)
    end,

    set_invoke_pending_lua = function (loop)
        evC.ev_set_invoke_pending_cb(loop, invoke_pending_cptr)
    end,

    set_invoke_pending_c = function (loop)
        evC.ev_set_invoke_pending_cb(loop, evC.ev_invoke_pending)
    end,

    feed_event = function (loop, w, revents)
        evC.ev_feed_event(loop, w, revents)
    end,

    feed_fd_event = function (loop, fd, revents)
        evC.ev_feed_fd_event(loop, fd, revents)
    end,

    feed_signal_event = function (loop, signum)
        evC.ev_feed_signal_event(loop, signum)
    end,
}})

ev.FLAG_AUTO = C.EVFLAG_AUTO
ev.FLAG_FORKCHECK = C.EVFLAG_FORKCHECK
ev.FLAG_NOENV = C.EVFLAG_NOENV
ev.FLAG_NOINOTIFY = C.EVFLAG_NOINOTIFY
ev.FLAG_SIGNALFD = C.EVFLAG_SIGNALFD
ev.FLAG_NOSIGMASK = C.EVFLAG_NOSIGMASK

ev.BACKEND_EPOLL = C.EVBACKEND_EPOLL
ev.BACKEND_POLL = C.EVBACKEND_POLL
ev.BACKEND_SELECT = C.EVBACKEND_SELECT

ev.UNDEF = C.EV_UNDEF
ev.NONE = C.EV_NONE
ev.READ = C.EV_READ
ev.WRITE = C.EV_WRITE
ev.IO = C.EV_IO
ev.TIMER = C.EV_TIMER
ev.PERIODIC = C.EV_PERIODIC
ev.SIGNAL = C.EV_SIGNAL
ev.CHILD = C.EV_CHILD
ev.STAT = C.EV_STAT
ev.IDLE = C.EV_IDLE
ev.PREPARE = C.EV_PREPARE
ev.CHECK = C.EV_CHECK
ev.EMBED = C.EV_EMBED
ev.FORK = C.EV_FORK
ev.CLEANUP = C.EV_CLEANUP
ev.ASYNC = C.EV_ASYNC
ev.CUSTOM = C.EV_CUSTOM
ev.ERROR = C.EV_ERROR

ev.RUN_NOWAIT = C.EVRUN_NOWAIT
ev.RUN_ONCE = C.EVRUN_ONCE

ev.BREAK_CANCEL = C.EVBREAK_CANCEL
ev.BREAK_ONE = C.EVBREAK_ONE
ev.BREAK_ALL = C.EVBREAK_ALL

local Watcher = {
    is_active = function (w)
        return w._wC.active ~= 0
    end,

    is_pending = function (w)
        return w._wC.pending ~= 0
    end,

    priority = function (w)
        return tonumber(w._wC.priority)
    end,

    set_priority = function (w, prio)
        w._wC.priority = prio
    end,

    clear_pending = function (w, loop)
        return evC.ev_clear_pending(loop or ev.default_loop(), w)
    end,

    feed_event = function (w, loop, revents)
        evC.ev_feed_event(loop or ev.default_loop(), w, revents)
    end,
}
Watcher.__index = Watcher

local IO = setmetatable({
    start = function (w, loop)
        if w:is_active() then return end
        w._wC.fd = w.fd
        w._wC.events = bit.bor(w.events, C.EV__IOFDSET)
        activate_watcher(w, w.cb)
        evC.ev_io_start(loop or ev.default_loop(), w._wC)
    end,

    stop = function (w, loop)
        if not w:is_active() then return end
        evC.ev_io_stop(loop or ev.default_loop(), w._wC)
        deactivate_watcher(w)
    end,
}, Watcher)
IO.__index = IO

function ev.io_new(cb, fd, events)
    local w = {
        _wC = ffi.new('ev_io', { cb = lua_cb_trampoline_cptr }),
        cb = cb,
        fd = fd,
        events = events
    }
    return setmetatable(w, IO)
end

local Timer = setmetatable({
    start = function (w, loop, at, rep)
        if w:is_active() then return end
        if type(loop) == 'number' then
            loop, at, rep = nil, loop, at
        end
        w.at = at or w.at
        w.rep = rep or w.rep
        w._wC.at = w.at or 0
        w._wC['repeat'] = w.rep or 0
        activate_watcher(w, w.cb)
        evC.ev_timer_start(loop or ev.default_loop(), w._wC)
    end,

    again = function (w, loop, rep)
        if type(loop) == 'number' then
            loop, rep = nil, loop
        end
        w.rep = rep or w.rep
        w._wC['repeat'] = w.rep or 0
        evC.ev_timer_again(loop, w._wC)
    end,

    remaining = function (w, loop)
        return evC.ev_timer_remaining(loop or ev.default_loop(), w._wC)
    end,

    stop = function (w, loop)
        if not w:is_active() then return end
        evC.ev_timer_stop(loop or ev.default_loop(), w._wC)
        deactivate_watcher(w)
    end,
}, Watcher)
Timer.__index = Timer

function ev.timer_new(cb, at, rep)
    local w = {
        _wC = ffi.new('ev_timer', { cb = lua_cb_trampoline_cptr }),
        cb = cb,
        at = at,
        rep = rep,
    }
    return setmetatable(w, Timer)
end

local Signal = setmetatable({
    start = function (w, loop)
        if w:is_active() then return end
        w._wC.signum = w.signum
        activate_watcher(w, w.cb)
        evC.ev_signal_start(loop or ev.default_loop(), w._wC)
    end,

    stop = function (w, loop)
        if not w:is_active() then return end
        evC.ev_signal_stop(loop or ev.default_loop(), w._wC)
        deactivate_watcher(w)
    end,
}, Watcher)
Signal.__index = Signal

function ev.signal_new(cb, signum)
    local w = {
        _wC = ffi.new('ev_signal', { cb = lua_cb_trampoline_cptr }),
        cb = cb,
        signum = signum,
    }
    return setmetatable(w, Signal)
end

local Idle = setmetatable({
    start = function (w, loop)
        if w:is_active() then return end
        activate_watcher(w, w.cb)
        evC.ev_idle_start(loop or ev.default_loop(), w._wC)
    end,

    stop = function (w, loop)
        if not w:is_active() then return end
        evC.ev_idle_stop(loop or ev.default_loop(), w._wC)
        deactivate_watcher(w)
    end,
}, Watcher)
Idle.__index = Idle

function ev.idle_new(cb)
    local w = {
        _wC = ffi.new('ev_idle', { cb = lua_cb_trampoline_cptr }),
        cb = cb,
    }
    return setmetatable(w, Idle)
end

if false then
    return ev
end

local loop = ev.default_loop(ev.BACKEND_POLL + ev.FLAG_NOSIGMASK)
print('loop', loop)
print('iteration', loop:iteration())
print('depth', loop:depth())
print('now', loop:now())
print('run', loop:run())

local sig = ev.signal_new(function (loop, w, revents)
    print('signal watcher', loop, w, revents)
    w:stop()
end, C.SIGUSR1)
sig:start()
C.kill(C.getpid(), C.SIGUSR1)
print('run', loop:run())

local fd = C.open('/dev/urandom', C.O_RDONLY)
print('fd', fd)
local iow = ev.io_new(function (loop, w, revents)
    print('io watcher', loop, w, w.fd, w._wC.fd, w._wC.events, revents, w.count)
    print('revents', string.format('%08x', revents))
    if bit.band(revents, ev.ERROR) ~= 0 then
        error('wtf?')
    end
    w.count = w.count + 1
    if w.count > 10 then
        print('stop?')
        w:stop()
    end
end, fd, ev.READ)
iow.count = 0
iow:start()
print('iow', iow)
print('iow:priority()', iow:priority())
iow:set_priority(2)
print('iow:priority()', iow:priority())
print('run', loop:run())
C.close(fd)

local timer = ev.timer_new(function (loop, w, revents)
    print('timer!', loop, w, revents, w.stuff)
    print('iteration', loop:iteration())
    print('depth', loop:depth())
    w.count = w.count and w.count + 1 or 1
    print('w.count', w.count)
    print('w._wC.at', w._wC.at)
    print('w._wC.repeat', w._wC['repeat'])
    print('remaining', w:remaining())
    if w.count > 10 then
        loop:brk(ev.BREAK_ONE)
    end
end, 1, 1)
timer.stuff = 'foo'
timer:start(0.1, 0.1)
print('timer', timer)
print('remaining', timer:remaining())
print('run', loop:run())
timer:stop()
print('timer._wC.at', timer._wC.at)
print('timer._wC.repeat', timer._wC['repeat'])

local timer = ev.timer_new(function (loop, w, revents)
    print('timer 2!', loop, w, revents, w.stuff)
    w.count = w.count and w.count + 1 or 1
    print('w.count', w.count)
    if w.count < 10 then
        w:start(0.1)
    end
end)
timer:start(0.1)
print('run', loop:run())

local count = 0
local idle = ev.idle_new(function (loop, w, revents)
    count = count + 1
    if count > 1000 then
        w:stop()
    end
end)
idle:start()
print('idle', idle)
print('run', loop:run())
