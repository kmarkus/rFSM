
local rfsm = require "rfsm"

local cnt = 10000
print("ping ponging " .. tostring(cnt) .. " times")

local function check_cnt()
   if cnt < 0 then os.exit() end
   cnt = cnt - 1
end

fsm = rfsm.init( 
   rfsm.csta {
      ping = rfsm.sista{ entry=check_cnt },
      pong = rfsm.sista{ entry=check_cnt },
   
      rfsm.trans{src="initial", tgt="ping" },
      rfsm.trans{src="ping", tgt="pong", events={"e_done"}},
      rfsm.trans{src="pong", tgt="ping", events={"e_done"}},
   })

rfsm.run(fsm)