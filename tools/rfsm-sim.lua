-- -*- lua -*-
local rfsm = require("rfsm")
local rfsmpp = require("rfsmpp")
local utils = require("utils")

local fsm

if arg and #arg < 1 then
   print("usage: rfsm-sim <fsmfile>")
   os.exit(1)
end

file = arg[1]
tmpdir="/tmp/"

-- change_hooks handling
local change_hooks = {}
local function run_hooks()
   for _,f in ipairs(change_hooks) do f() end
end

function add_hook(f)
   assert(type(f) == 'function', "add_hook argument must be function")
   change_hooks[#change_hooks+1] = f
end

-- debugging
function dbg(mode)
   if not mode then fsm.dbg=function(...) return end
   elseif mode=='full' then
      fsm.dbg=rfsmpp.gen_dbgcolor(file)
   else
      fsm.dbg=rfsmpp.gen_dbgcolor(file, {STATE_ENTER=true, STATE_EXIT=true, RAISED=true}, false)
   end
end

-- operational
function se(...)
   rfsm.send_events(fsm, ...)
end

function ses(...)
   rfsm.send_events(fsm, ...)
   rfsm.step(fsm)
   run_hooks()
end

function ser(...)
   rfsm.send_events(fsm, ...)
   rfsm.run(fsm)
   run_hooks()
end

function run()
   rfsm.run(fsm);
   run_hooks()
end

function sim()
   require "rfsm_proto"
   fsm.idle_hook = function () os.execute("sleep 0.1") end
   rfsm_proto.install(fsm)
   run()
end

function step(n)
   n = n or 1
   rfsm.step(fsm, n)
   run_hooks()
end

-- visualisation
function pp()
   print(rfsmpp.fsm2str(fsm))
end

function showfqn()
   local actfqn
   if fsm._actchild then
      actfqn = fsm._actchild._fqn .. '(' .. rfsm.get_sta_mode(fsm._actchild) .. ')'
   else
      actfqn = "<none>"
   end
   print("active: " .. actfqn)
end

function showeq()
   rfsm.check_events(fsm)
   print("queue:  " .. table.concat(utils.map(tostring, fsm._intq), ', '))
end

function boiler()
   print("rFSM simulator v0.1, type 'help()' to list available commands")
end

function help()
   print([=[

available commands:
   help()         -- show this information
   dbg(mode)      -- enable/disable debug info (mode=false|true|"full")
   se(...)        -- send events
   ses(...)       -- send events and step(1)
   ser(...)       -- send events and run()
   run()          -- run FSM
   step(n)        -- step FSM n times
   pp()           -- pretty print fsm
   showeq()       -- show current event queue
   add_hook(func) -- add a function to be called after state changes (e.g. 'add_hook(pp)')
	 ]=])
end

boiler()
local _fsm=rfsm.load(file)

local ok
ok, fsm = xpcall(rfsm.init, debug.traceback, _fsm)

if not ok or not fsm then
   print("rfsm-sim: failed to initialize fsm:", fsm)
   os.exit(1)
end

add_hook(showfqn)
add_hook(showeq)
dbg(false)
