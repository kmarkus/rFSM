--
-- Various pretty printing functions to make life easier
--
-- (C) 2010-2013 Markus Klotzbuecher <markus.klotzbuecher@mech.kuleuven.be>
-- (C) 2014-2020 Markus Klotzbuecher <mk@mkio.de>
--
-- SPDX-License-Identifier: BSD-3-Clause
--

local ansicolors = require("ansicolors")
local utils = require("utils")
local rfsm = require("rfsm")

local print, type, pairs, assert = print, type, pairs, assert
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

local M = {}

local pad = 20

-- pretty print fsm
function M.fsm2str(fsm, ind)
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

function M.dbgcolorize(name, ...)
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

   return str
end

--- Colorized fsm.dbg hook replacement.
function M.dbgcolor(name, ...)
    print(M.dbgcolorize(name, ...))
end

--- Generate a configurable dbgcolor function.
-- @param name string name to prepend to printed message.
-- @param ftab table of the dbg ids to print.
-- @param defshow if false fields not mentioned in ftab are not shown. If true they are.
-- @param print_fcn a function actually used for printing. Defaults to print.
function M.gen_dbgcolor(name, ftab, defshow, print_fcn)
   name = name or "<unnamed SM>"
   ftab = ftab or {}
   if defshow == nil then defshow = true end
   if print_fcn == nil then print_fcn = print end

   return function (tag, ...)
      if ftab[tag] == true then print_fcn(M.dbgcolorize(name, tag, ...))
      elseif ftab[tag] == false then return
      else if defshow then print_fcn(M.dbgcolorize(name, tag, ...)) end end
   end
end

return M
