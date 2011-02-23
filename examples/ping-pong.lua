
local rfsm = require "rfsm"

local cnt = 1000000
print("ping ponging " .. tostring(cnt) .. " times")

local function check_cnt()
   if cnt < 0 then os.exit() end
   cnt = cnt - 1
end

fsm = rfsm.init( 
   rfsm.csta:new {
      ping = rfsm.sista:new{ entry=check_cnt },
      pong = rfsm.sista:new{ entry=check_cnt },
   
      rfsm.trans:new{src="initial", tgt="ping" },
      rfsm.trans:new{src="ping", tgt="pong", events={"e_done"}},
      rfsm.trans:new{src="pong", tgt="ping", events={"e_done"}},
   })

rfsm.run(fsm)