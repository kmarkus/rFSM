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

-- colorized dbg replacement function
function dbgcolor(...)

   if not type(arg) == 'table' then
      return
   end

   arg.n = nil -- oh why!

   -- convert nested tables to strings
   ptab = utils.map(function (e) return utils.tab2str(e) end, arg)

   local ctab = {
      STATE_ENTER = ac.green,
      STATE_EXIT = ac.red,
      EFFECT = ac.yellow,
      DOO = ac.blue,
      EXEC_PATH = ac.cyan,
      ERROR = ac.red .. ac.bright,
      HIBERNATING = ac.magenta
   }

   col = ctab[ptab[1]]

   if col ~= nil then
      print(col .. utils.rpad(ptab[1], 18) .. ac.reset .. table.concat(ptab, ' ', 2))
   else
      print(utils.rpad(ptab[1], 18) .. table.concat(ptab, ' ', 2))
   end
end

