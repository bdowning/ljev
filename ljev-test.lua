-- Copyright (C) 2014-2015 Brian Downing.  MIT License.

local ev = require 'ljev'

local count = 0
local function cb(loop, w, revents)
    local div_cnt = count / 1000000
    if math.floor(div_cnt) == div_cnt then
        io.stdout:write(tostring(count), '\n')
    end
    if count == 20000000 then
        loop:brk(ev.BREAK_ALL)
    end
    count = count + 1
end

local loop = ev.default_loop()

for i = 1, 6 do
    local timer = ev.idle_new(cb, 0.002, 0.002)
    timer:start(loop)
end

ev.prepare_new(function () end):start()

loop:run()
print(loop:iteration())
