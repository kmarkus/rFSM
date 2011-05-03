--
-- This module contains some useful functions for using the rfsm
-- statecharts together with OROCOS RTT.
--

local rtt = rtt
local string = string
local assert, ipairs, pairs, type, error = assert, ipairs, pairs, type, error

module("rfsm_rtt")


--- Generate an event reader function.
--
-- When called this function will read all new events from the given
-- dataports and return them in a table.
--
-- @param ... list of ports to read events from
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

--- Generate a function which writes the fsm fqn to a port.
--
-- This function returns a function which takes a rfsm instance as the
-- single parameter and write the fully qualifed state name of the
-- active leaf to the given string rtt.OutputPort. Intended to be
-- added to the fsm step_hook.
--
-- @param port rtt OutputPort to which the fqn shall be written
-- @param filter: function which must take a variable of type and a
-- string fqn and assigns the string to the variable and returns it
-- (optional)

function gen_write_fqn(port, filter)
   local type = port:info().type --todo check for filter?
   if type ~= 'string' and type(filter) ~= 'function' then
      error("use of non string type " .. type .. " requires a filter function")
   end

   local act_fqn = ""
   local _f = filter or function (var, fqn) var:assign(fqn); return var end
   local out_dsb = rtt.Variable.new(type)

   port:write(_f(out_dsb, "<none>")) -- initial val

   return function (fsm)
	     if not fsm._act_leaf then return
	     elseif act_fqn == fsm._act_leaf._fqn then return end

	     act_fqn = fsm._act_leaf._fqn
	     port:write(_f(out_dsb, act_fqn))
	  end
end


--- Lauch an rFSM statemachine in a RTT Lua Service.
--
-- This function launches an rfsm statemachine in the given file
-- (specified with return csta:new{}) into a service, and optionally
-- install a eehook so that it will be periodically triggerred. It
-- also create a port "fqn" in the TC's interface where it writes the
-- active. Todo: this could be done much nicer with cosmo, if we chose
-- to add that dependency.
-- @param file file containing the rfsm model
-- @param execstr_f exec_string function of the service. retrieve with compX:provides("Lua"):getOperation("exec_str")
-- @param eehook boolean flag, if true eehook for periodic triggering is setup
-- @param env table with a environment of key value pairs which will be defined in the service before anything else
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


   s[#s+1] = '_fsm = rfsm.load("' .. file .. '")'
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
