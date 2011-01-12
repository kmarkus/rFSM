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
-- Lightweight rFSM Statechart debugger
--

--
-- Minimal set of required commands:
--   - send(event)
--   - ping

-- command structure:
-- { cmd="command", data="" }
-- { cmd="ping" }
--
-- reply:
-- { res="pong" }



require("socket")
require("utils")
require("json")

local assert = assert
local setmetatable = setmetatable
local type = type
local ipairs = ipairs
local print = print
local socket = socket
local table = table
local utils = utils
local json = json
local os = os

module("fsmdbg")

-- defaults
local timeout = 3
local defport = 33003


--
-- client part
--

-- ok for cli
local out = print
local err = print
local dbg = print

cli = {}

function cli:new(host, port)
   local t = {}

   t.tgtport = port or defport
   t.tgtip = assert(socket.dns.toip(host))
   t.sock = assert(socket.udp())
   assert(t.sock:setsockname("*", 0))
   assert(t.sock:setpeername(t.tgtip, t.tgtport))
   assert(t.sock:settimeout(timeout))
   
   setmetatable(t, self)
   self.__index = self

   local res, errmes = t:ping()
   if not res then
      err("Error: can't connect to " .. host .. ":" .. t.tgtport .. ": " .. errmes)
      return false
   end

   return t
end

function cli:ping()
   local res = false
   local errmes
   self:__send{cmd="ping"}
   local mes, data = self:__receive()
   if not mes then
      res = false
      errmes = "ping timeout"
   elseif mes.res == "pong" then
      res = true
   else
      res = false
      errmes = "unknown response:" .. data
   end
   return res, errmes
end

function cli:kill()
   self:__send{cmd="killfsm"}
   local mes, data = self:__receive()
   if not mes then
      res = false
   elseif mes.res == "exiting" then
      res = true
   else
      res = false
      errmes = "unknown response:" .. data
   end
   return res, errmes
end


function cli:__send(tab)
   assert(type(tab) == 'table')
   return self.sock:send(json.encode(tab))
end

function cli:__receive()
   local data = self.sock:receive()
   local res
   if not data then
      return false
   end
   return json.decode(data), data
end

function cli:sendev(...)
   for i,e in ipairs(arg) do
      self:__send{cmd="sendevent", data=e}
   end
end

--
-- Server
--

--
-- the FSM hook: generate two debug functions which can be called by
-- the rFSM engine
-- 
-- Parameters: 
--     - fsm: used to print error message with fsm.err
--     - port (optional) port to listen for commands (default 33003)
--
-- Return values: process(function), getevents(function)
--     - process: will process all commands reveived
--     - getevents: call process and clears and returns the current event queue
--
-- Rationale: process should be called in step_hook in order
-- continuously process incoming commands and getevents can be added
-- to getevents queue.
-- 
local function gen_dbghooks(fsm, port)
   local s = assert(socket.udp())
   local evq = {}

   assert(s:setsockname("*", port or defport))
   s:settimeout(0)
   
   local process = function ()
		      while true do
			 local data, ip, port = s:receivefrom()
			 if not data then return end
		      
			 local mes = json.decode(data)
			 
			 if mes.cmd == "ping" then
			    s:sendto(json.encode{res="pong"}, ip, port)
			 elseif mes.cmd == "sendevent" then
			    evq[#evq+1] = mes.data
			 elseif mes.cmd == "killfsm" then
			    s:sendto(json.encode{res="exiting"}, ip, port)
			    fsm.info("fsmdbg: calling os.exit")
			    os.exit(0)
			 else
			    fsm.err("fsmdbg.process: unknown command: ", data)
			 end
		      end
		   end

   -- return closure
   return function ()
	     process()
	     local res = evq
	     evq = {}
	     return res
	  end
end

function enable(fsm, port)
   local getevents = gen_dbghooks(fsm, port)

   -- tbd: don't overwrite but use aspect
   fsm.getevents = getevents
end