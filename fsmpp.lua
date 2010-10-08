--
-- This file is part of rFSM.
--
-- rFSM is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- rFSM is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
-- License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with rFSM.  If not, see <http://www.gnu.org/licenses/>.
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
local is_sta = rfsm.is_sta
local is_sista = rfsm.is_sista
local is_csta = rfsm.is_csta
local sta_mode = rfsm.sta_mode
local fsmobj_tochar = rfsm.fsmobj_tochar

module("fsmpp")


local pad = 20

-- pretty print fsm
function fsm2str(fsm, ind)
   local ind = ind or 1
   local indstr = '    '
   local res = {}

   function __2colstr(s)
      assert(s, "s not a state")
      if s._mode == 'active' then
	 if is_sista(s) then return ac.green .. ac.bright .. s._id .. ac.reset
	 else return ac.green .. s._id .. ac.reset end
      elseif s._mode == 'done' then return ac.yellow .. s._id .. ac.reset
      else return ac.red .. s._id .. ac.reset end
   end

   function __fsm_tostring(tab, res, ind)
      for name,state in pairs(tab) do
	 if not is_meta(name) and is_sta(state) then
	    res[#res+1] = string.rep(indstr, ind) .. __2colstr(state) .. '[' .. fsmobj_tochar(state) .. ']'
	    if is_sista(state) then res[#res+1] = '\n' end
	    if is_csta(state) then
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


-- colorized dbg replacement function
function dbgcolor(...)

   if not type(arg) == 'table' then
      return
   end

   arg.n = nil -- argh !

   -- convert nested tables to strings
   ptab = utils.map(function (e) return utils.tab2str(e) end, arg)

   local ctab = {
      STATE_ENTER = ac.green,
      STATE_EXIT = ac.red,
      EFFECT = ac.yellow,
      DOO = ac.blue,
      EXEC_PATH = ac.cyan,
      ERROR = ac.red .. ac.bright,
      HIBERNATING = ac.magenta,
      RAISED = ac.white .. ac.bright
   }

   col = ctab[ptab[1]]

   if col ~= nil then
      print(col .. utils.rpad(ptab[1], pad) .. ac.reset .. table.concat(ptab, ' ', 2))
   else
      print(utils.rpad(ptab[1], pad) .. table.concat(ptab, ' ', 2))
   end
end

-- returns a dbg color function which filters: first keeps the
-- attributes in pos, then from the remaining removes the ones with
-- attributes in tneg.
--
function gen_dbgcolor(ftab)

   return function (...)
	     local tag = arg[1]
	     arg.n = nil
	     if ftab[tag] == true then
		dbgcolor(unpack(arg))
	     elseif ftab[tag] == false then
		return
	     else
		if ftab['*'] then
		   dbgcolor(unpack(arg))
		end
	     end
	  end
end
