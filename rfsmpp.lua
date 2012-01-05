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
-- Various pretty printing functions to make life easier
--

require("ansicolors")
require("utils")
require("rfsm")

local unpack, print, type, pairs, assert = unpack, print, type, pairs, assert
local table = table
local utils = utils
local string = string
local ac = ansicolors
local rfsm = rfsm

-- some shortcuts
local is_meta = rfsm.is_meta
local is_state = rfsm.is_state
local is_leaf = rfsm.is_leaf
local is_composite = rfsm.is_composite
local sta_mode = rfsm.sta_mode
local fsmobj_tochar = rfsm.fsmobj_tochar

module("rfsmpp")


local pad = 20

-- pretty print fsm
function fsm2str(fsm, ind)
   local ind = ind or 1
   local indstr = '    '
   local res = {}

   function __2colstr(s)
      assert(s, "s not a state")
      if s._mode == 'active' then
	 if is_leaf(s) then return ac.green .. ac.bright .. s._id .. ac.reset
	 else return ac.green .. s._id .. ac.reset end
      elseif s._mode == 'done' then return ac.yellow .. s._id .. ac.reset
      else return ac.red .. s._id .. ac.reset end
   end

   function __fsm_tostring(tab, res, ind)
      for name,state in pairs(tab) do
	 if not is_meta(name) and is_state(state) then
	    res[#res+1] = string.rep(indstr, ind) .. __2colstr(state) .. '[' .. fsmobj_tochar(state) .. ']'
	    if is_leaf(state) then res[#res+1] = '\n' end
	    if is_composite(state) then
	       res[#res+1] = '\n'
	       __fsm_tostring(state, res, ind+1)
	    end
	 end
      end
   end
   res[#res+1] = __2colstr(fsm) .. '\n'
   __fsm_tostring(fsm, res, ind)
   return table.concat(res, '')
end


--- Debug message colors.
local ctab = {
   STATE_ENTER = ac.green,
   STATE_EXIT = ac.red,
   EFFECT = ac.yellow,
   DOO = ac.blue,
   EXEC_PATH = ac.cyan,
   ERROR = ac.red .. ac.bright,
   HIBERNATING = ac.magenta,
   RAISED = ac.white .. ac.bright,
   TIMEEVENT = ac.yellow .. ac.bright
}

--- Colorized fsm.dbg hook replacement.
function dbgcolor(name, ...)
   local str = ""
   local args = { ... }

   if name then str = ac.cyan .. ac.bright .. name .. ":" .. ac.reset .. '\t' end

   -- convert nested tables to strings
   ptab = utils.map(utils.tab2str, args)
   col = ctab[ptab[1]]

   if col ~= nil then
      str = str.. col .. utils.rpad(ptab[1], pad) .. ac.reset .. table.concat(ptab, ' ', 2)
   else
      str = str .. utils.rpad(ptab[1], pad) .. table.concat(ptab, ' ', 2)
   end
   print(str)
end

--- Generate a configurable dbgcolor function.
-- @param name string name to prepend to printed message.
-- @param ftab table of the dbg ids to print.
-- @param defshow if false fields not mentioned in ftab are not shown. If true they are.
function gen_dbgcolor(name, ftab, defshow)
   name = name or "<unnamed SM>"
   ftab = ftab or {}
   if defshow == nil then defshow = true end

   return function (tag, ...)
	     if ftab[tag] == true then dbgcolor(name, tag, ...)
	     elseif ftab[tag] == false then return
	     else if defshow then dbgcolor(name, tag, ...) end end
	  end
end
