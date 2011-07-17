
require "rfsm"
require "rfsm_emem"

return rfsm.csta {
   ping = rfsm.sista{
      doo=function (fsm)
	     while true do
		rfsm.send_events(fsm, 'e_ping')
		rfsm.yield()
	     end
	  end,
   },

   pong = rfsm.sista{
      doo=function (fsm)
	     while true do
		rfsm.send_events(fsm, 'e_pong')
		rfsm.yield()
	     end
	  end,
   },

   rfsm.trans{ src='initial', tgt='ping' },
   rfsm.trans{ src='ping', tgt='pong', guard=function (tr)
						local x = tr.src.emem.e_ping
						if x and x > 10000 then return true end
						return false
					     end,
	       effect=function() print("to pong") end },

   rfsm.trans{ src='pong', tgt='ping', guard=function (tr)
						local x = tr.src.emem.e_pong
						if x and x > 20000 then return true end
						return false
					     end,
	       effect=function() print("to ping") end },
}