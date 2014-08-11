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
loop:set_invoke_pending_lua()

for i = 1, 6000 do
    local timer = ev.timer_new(cb, 0.002, 0.002)
    timer:start(loop)
end

loop:run()
