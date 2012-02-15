--
-- This file is part of rFSM.
--
-- (C) 2010,2011 Markus Klotzbuecher, markus.klotzbuecher@mech.kuleuven.be,
-- Department of Mechanical Engineering, Katholieke Universiteit
-- Leuven, Belgium.
--
-- You may redistribute this software and/or modify it under either
-- the terms of the GNU Lesser General Public License version 2.1
-- (LGPLv2.1 <http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html>)
-- or (at your discretion) of the Modified BSD License: Redistribution
-- and use in source and binary forms, with or without modification,
-- are permitted provided that the following conditions are met:
--    1. Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--    2. Redistributions in binary form must reproduce the above
--       copyright notice, this list of conditions and the following
--       disclaimer in the documentation and/or other materials provided
--       with the distribution.
--    3. The name of the author may not be used to endorse or promote
--       products derived from this software without specific prior
--       written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
-- OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
-- GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
-- WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
-- NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--

---
-- This module contains some useful functions for using the rfsm
-- statecharts together with OROCOS RTT.
--

require "rttlib"
require "utils"

local rtt = rtt
local rttlib = rttlib
local string = string
local utils = utils
local print = print
local assert, ipairs, pairs, type, error, tostring = assert, ipairs, pairs, type, error, tostring

module("rfsm_rtt")


--- Generate an event reader function.
--
-- When called this function will read all new events from the given
-- dataports and return them in a table.
--
-- @param ... list of ports to read events from
-- @return getevent function
function gen_read_events(...)
   local str_ev = rtt.Variable("string")

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

--- Generate an event reader function optimized for string events.
--
-- When called this function will read all new events from the given
-- dataports and return them in a table.
--
-- @param ... list of ports to read events from
-- @return getevent function
function gen_read_str_events(...)
   local str_ev = rtt.Variable("string")
   local function read_events(tgttab, port)
      local fs
      while true do
	 fs = port:read(str_ev)
	 if fs == 'NewData' then tgttab[#tgttab+1] = str_ev:tolua()
	 else break end -- OldData or NoData
      end
   end

   local ports = {...}
   assert(#ports > 0, "no ports given")
   -- check its all ports
   return function ()
	     local res = {}
	     for _,port in ipairs(ports) do read_events(res, port) end
	     return res
	  end
end

--- Generate an event raising function.
--
-- The generated function accepts zero to many arguments and writes
-- them to the given port (and if the fsm argument is provided) to the
-- internal queue of fsm.
-- @param port outport to write events to
-- @param fsm events are sent to this fsm's internal queue (optional)
-- @return function to send events to the port
function gen_raise_event(port, fsm)
   assert(port, "No port specified")
   return function (...) for
	  _,e in ipairs{...} do port:write(e) end
       if fsm then rfsm.send_events(fsm, ...) end
    end
end


--- Generate a function which writes the fsm fqn to a port.
--
-- This function returns a function which takes a rfsm instance as the
-- single parameter and write the fully qualifed state name of the
-- active leaf to the given string rtt.OutputPort. To be added to the
-- fsm post_step_hook.
-- @param port rtt OutputPort to which the fqn shall be written
function gen_write_fqn(port)
   assert(port:info().type=='string', "gen_write_fqn: port must be of type string")

   local act_fqn = ""
   local out_dsb = rtt.Variable.new('string')

   port:write(out_dsb, "<none>") -- initial val

   return function (fsm)
	     local actl = fsm._act_leaf
	     if not actl or act_fqn == actl._fqn then return end
	     act_fqn = actl._fqn
	     out_dsb:assign(act_fqn)
	     port:write(out_dsb, act_fqn)
	  end
end


--- Lauch an rFSM statemachine in a RTT Lua Service.
--
-- This function launches an rfsm statemachine in the given file
-- (specified with return rfsm.state{}) into a service, and optionally
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

   s[#s+1] = "require 'rttlib'"
   s[#s+1] = "require 'rfsm'"
   s[#s+1] = "require 'rfsm_rtt'"
   s[#s+1] = "require 'utils'"

   if env and type(env) == 'table' then
      for k,v in pairs(env) do s[#s+1] = k .. '=' .. '"' .. v .. '"' end
   end

   s[#s+1] = [[
	 fqn = rtt.OutputPort("string", "fqn", "rFSM currently active fully qualified state name")
	 rtt.getTC():addPort(fqn)
	 setfqn = rfsm_rtt.gen_write_fqn(fqn)
   ]]


   s[#s+1] = '_fsm = rfsm.load("' .. file .. '")'
   s[#s+1] = "fsm = rfsm.init(_fsm)"
   s[#s+1] = "rfsm.post_step_hook_add(fsm, setfqn)"
   s[#s+1] = [[ function trigger()
		   rfsm.step(fsm)
		   return true
		end ]]

   if eehook then
      s[#s+1] = 'eehook = rtt.EEHook("trigger")'
      s[#s+1] = "eehook:enable()"
   end

   for _,str in ipairs(s) do
      assert(execstr_f(str), "Error launching rfsm: executing " .. str .. " failed")
   end

end


--- Launch a rFSM in a component.
--
-- Will first create a Lua rFSM Component.
-- Next the following is done: require "rttlib" and "rFSM",
-- set environment variables, execute prefile, setup outport for FSM
-- status, load rFSM, define updateHook and finally execute postfile.
-- @param argtab table with the some or more of the following fields:
--    - fsmfile rFSM file (required)
--    - name of component to be create (required)
--    - deployer deployer to use for creating LuaComponent (required)
--    - luatype type of lua component to create. (default: OCL::LuaComponent)
--    - sync boolean flag. If true rfsm.step() will be called in updateHook, otherwise rfsm.run(). default=false.
--    - ev_inport. If not false or nil will create an inport and connect 'getevents' to it. If a string it will be used as the Port name.
--    - prefile Lua script file executed before loading rFSM for preparing the environment.
--    - postfile Lua script file executed after loading rFSM.
--    - env environment table of key-value pairs which are initalized in the new component. Used for parametrization.
function component_launch_rfsm(argtab)
   assert(argtab and type(argtab) == 'table', "No argument table given")
   assert(type(argtab.name) == 'string', "No 'name' specified")
   assert(type(argtab.fsmfile) == 'string', "No 'fsmfile' specified")
   assert(type(argtab.deployer) == 'userdata', "No 'deployer' provided")

   if not argtab.luatype then
      argtab.luatype = "OCL::LuaComponent"
   end

   local depl=argtab.deployer
   local name=argtab.name
   local fsmfile=argtab.fsmfile

   if not depl:loadComponent(name, argtab.luatype) then
      error("Failed to create lua component (" .. argtab.luatype .. ")")
   end

   comp=depl:getPeer(name)
   comp:addPeer(depl)
   exec_str = comp:provides():getOperation("exec_str")
   exec_file = comp:provides():getOperation("exec_file")

   local s = {}
   s[#s+1] = "require 'rttlib'"
   s[#s+1] = "require 'rfsm'"
   s[#s+1] = "require 'rfsm_rtt'"
   s[#s+1] = "require 'utils'"

   if argtab.env and type(argtab.env) == 'table' then
      for k,v in pairs(argtab.env) do s[#s+1] = k .. '=' .. '"' .. tostring(v) .. '"' end
   end

   for _,str in ipairs(s) do
      assert(exec_str(str), "Error launching rfsm: executing " .. str .. " failed")
   end
   s={}

   if argtab.prefile then exec_file(argtab.prefile) end

   s[#s+1] = [[fqn = rtt.OutputPort("string", "fqn", "rFSM currently active fully qualified state name")
	 rtt.getTC():addPort(fqn)
	 setfqn = rfsm_rtt.gen_write_fqn(fqn)
   ]]

   s[#s+1] = ([[_fsm = rfsm.load('%s')
		    fsm = rfsm.init(_fsm)
		    rfsm.post_step_hook_add(fsm, setfqn)
	      ]]):format(fsmfile)

   if argtab.sync then
      s[#s+1] = "function updateHook() rfsm.step(fsm) end"
   else
      s[#s+1] = "function updateHook() rfsm.run(fsm) end"
   end

   -- todo: properly delete this port again.
   if argtab.ev_inport then
      if type(argtab.ev_inport) ~= 'string' then argtab.ev_inport='events_in' end
      s[#s+1] = "ev_inport = rtt.InputPort('string', '" .. argtab.ev_inport .. "', 'Autogenerated event inport')"
      s[#s+1] = "rtt.getTC():addEventPort(ev_inport)"
      s[#s+1] = "fsm.getevents = rfsm_rtt.gen_read_events(ev_inport)"
   end

   for _,str in ipairs(s) do
      assert(exec_str(str), "Error launching rfsm: executing " .. str .. " failed")
   end
   s={}

   if argtab.postfile then exec_file(argtab.postfile) end

   return comp
end