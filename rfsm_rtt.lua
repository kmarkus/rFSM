--
-- This module contains some useful functions for using the rfsm
-- statecharts together with OROCOS RTT.
--

local rtt = rtt
local string = string

module("rfsm_rtt")

--
-- generates a function which reads all new events from the given
-- dataports and returns them in a table
--
function gen_read_events(...)

   local function read_events(tgttab, port)
      local fs,ev
      while true do
	 fs, ev = port:read()
	 if fs == 'NewData' then
	    tgttab[#tgtab+1] = ev 
	 else
	    break -- OldData or NoData
	 end
      end
   end

   local ports = {...}
   assert(#ports > 0, "no ports given")
   -- check its all ports
   return function ()
	     local res = {}
	     for _,port in ipairs(ports) do
		read_events(res, port)
	     end
	  end
end

-- generate a function which sends the fqn out through the given
-- dataport. To be added to step_hook
function gen_write_fqn(port)
   local act_fqn = "<none>"
   local out_dsb = rtt.Variable.new("string", string.rep(" ", 100))
   return function (fsm)
	     if act_fqn == fsm._act_leaf._fqn then return end
	     act_fqn = fsm._act_leaf._fqn
	     out_dsb:assign(act_fqn)
	     port:write(out_dsb)
	  end
end