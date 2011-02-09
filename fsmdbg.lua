--
-- This file is part of rFSM.
-- 
-- (C) 2010 Markus Klotzbuecher, markus.klotzbuecher@mech.kuleuven.be,
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