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

--
-- useful but non essential rFSM extensions
--

local rfsm = require("rfsm")
local utils = require("utils")
local pairs = pairs
local error = error
local type = type
local unpack = unpack
local setmetatable = setmetatable
local print = print

module("rfsm_ext")

--- gen_monitor_state argument table
-- Description of the table expected by the gen_monitor_state function
-- @class table
-- @name montab
-- @field entry entry function of state (optional)
-- @field exit exit function of state (optional)
-- @field exit exit function of state (optional)
-- @field montab table of monitor functions (required). The index is
-- the event which will be raised if the function returns true
-- @field break_first if set to true rfsm.yield will be called
-- immediately after the first monitor function returns true, opposed
-- to the default behavior which first calls all functions before
-- calling yield, thereby possibly generating multiple events.

--- generate a monitor state
-- This function generates a rfsm simple_state which repeatedly calls
-- a list of monitor functions and raises an associated event if the
-- function returns true.
-- @param t montab table
-- @retval an rfsm.simple_state object

function gen_monitor_state(t)
   if t.montab==nil or type(t.montab) ~= 'table' then
      error("gen_monitor_state: missing or invalid 'montab' argument")
   end
   local break_first = t.breakfirst

   return rfsm.sista {
      entry = t.entry or nil,
      exit = t.exit or nil,

      doo = function(fsm)
	       while true do
		  for ev,monfun in pairs(t.montab) do
		     if monfun() then
			rfsm.send_events(fsm, ev)
			if break_first then break end
		     end
		  end
		  rfsm.yield()
	       end
	       return true
	    end
   }
end


--- Sequential AND state
seqand = {}
function seqand:type() return 'simple' end

--- Sequential AND state constructor.
-- parameters:
--   t.idle_doo: returned in rfsm.yield(idle_doo) of seqand state.
--   t.step: number of steps to advance each subfsm
-- @param t initalized sub rfsm
function seqand:new(t)
   setmetatable(t, self)
   self.__index = self

   if t.run and t.step then
      error("Sequential AND state must define step or run")
   end

   if t.step and (type(t.step) ~= 'number' or t.step <= 0) then
      error("step must be a positive number")
   end

   if t.idle_doo == nil then t.idle_doo = true end

   local sh_saved
   -- entry install a new step hook (removed in exit) that intercepts
   -- and forward the current events to the child fsms.
   t.entry=function(fsm)
	      sh_saved=fsm.stephook
	      fsm.step_hook=function(fsm, events)
			       print("stephook intercepted events: ", utils.tab2str(events))
			       if sh_saved then sh_saved() end
			       rfsm.mapfsm(function (subfsm)
					      rfsm.send_events(subfsm, unpack(events))
					   end, t, rfsm.is_csta, 1)
			    end
	      rfsm.mapfsm(function (subfsm) rfsm.step(subfsm, t.step) end, t, rfsm.is_csta, 1)
	   end

   t.doo=function(fsm)
	    while true do
	       rfsm.mapfsm(function (subfsm)
			      rfsm.step(subfsm, t.step)
			   end, t, rfsm.is_csta, 1)
	       rfsm.yield(t.idle_doo)
	    end
	 end

   t.exit=function(fsm)
	     fsm.stephook=sh_saved
	     rfsm.mapfsm(function (subfsm)
			    rfsm.exit_state(subfsm, subfsm)
			    rfsm.reset(subfsm)
			 end, t, rfsm.is_csta, 1) end
   return t
end

setmetatable(seqand, {__call=seqand.new})
