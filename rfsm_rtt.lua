--
-- This module contains some useful functions for using the rfsm
-- statecharts together with OROCOS RTT.
--

local rtt = rtt
local string = string
local assert, ipairs, pairs, type = assert, ipairs, pairs, type

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
	    tgttab[#tgttab+1] = ev
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
	     return res
	  end
end

-- generate a function which sends the fqn out through the given
-- dataport. To be added to step_hook
function gen_write_fqn(port)
   local act_fqn = ""
   local out_dsb = rtt.Variable.new("string", string.rep(" ", 100))
   port:write("<none>") -- initial val

   return function (fsm)
	     if not fsm._act_leaf then return
	     elseif act_fqn == fsm._act_leaf._fqn then return end

	     act_fqn = fsm._act_leaf._fqn
	     out_dsb:assign(act_fqn)
	     port:write(out_dsb)
	  end
end


-- this function launches an rfsm statemachine in the given file
-- (specified with return csta:new{}) into a service, and optionally
-- install a eehook so that it will be periodically triggerred.
--
-- also create a port "fqn" in the TC's interface where it writes its fqn.
-- service_launch_rfsm(file, execstr_t, eehook) 
--   file: string filename
--   execstr_f: exec_string function of the resp. service
--   eehook: bool flag, if true create and enable eehook for periodic triggering.
--
-- todo: this could be done much nicer with cosmo, if we chose to add
-- that dependency.
function service_launch_rfsm(file, execstr_f, eehook, env)
   local s = {}

   if env and type(env) == 'table' then
      for k,v in pairs(env) do s[#s+1] = k .. '=' .. '"' .. v .. '"' end
   end

   s[#s+1] = [[
	 fqn = rtt.OutputPort.new("string", "fqn", "fsm fqn status")
	 rtt.getTC():addPort(fqn)
	 setfqn = rfsm_rtt.gen_write_fqn(fqn)
   ]]


   s[#s+1] = '_fsm = dofile("' .. file .. '")'
   s[#s+1] = "fsm = rfsm.init(_fsm)"
   s[#s+1] = "fsm.step_hook = setfqn"
   s[#s+1] = [[ function trigger()
		   rfsm.step(fsm)
		   return true
		end ]]

   if eehook then
      s[#s+1] = 'eehook = rtt.EEHook.new("trigger")'
      s[#s+1] = "eehook:enable()"
   end

   for _,str in ipairs(s) do
      assert(execstr_f(str), "Error launching rfsm: executing " .. str .. " failed")
   end

end
