--
-- Various pretty printing functions to make life easier
--

require("ansicolors")
require("utils")

local unpack, print, type = unpack, print, type
local table = table
local utils = utils
local ac = ansicolors

module("fsmpprint")


local pad = 20

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
