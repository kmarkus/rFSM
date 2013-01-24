-- -*- lua -*-
require "rfsm"
require "rfsmpp"
require "rfsm2uml"
require "rfsm2tree"

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
   rfsm.send_events(fsm, unpack(arg))
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

function uml()
   rfsm2uml.rfsm2uml(fsm, "png", tmpdir .. "rfsm-uml-tmp.png")
end

function tree()
   rfsm2tree.rfsm2tree(fsm, "png",  tmpdir .. "rfsm-tree-tmp.png")
end

function dot()
   rfsm2uml.rfsm2dot(fsm, tmpdir .. "rfsm-tmp-uml.dot")
end

function vizuml()
   local viewer = os.getenv("RFSM_VIEWER") or "firefox"
   uml()
   add_hook(uml)
   os.execute(viewer .. " " ..  tmpdir .. "rfsm-uml-tmp.png" .. "&")
end

function viztree()
   tree()
   add_hook(tree)
   local viewer = os.getenv("RFSM_VIEWER") or "firefox"
   os.execute(viewer .. " " .. tmpdir .. "rfsm-tree-tmp.png" .. "&")
end

function vizxdot()
   dot()
   add_hook(dot)
   os.execute("xdot " .. tmpdir .. "rfsm-tmp-uml.dot &")
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
   uml()          -- generate uml figure
   vizuml()       -- show uml figure ($RFSM_VIEWER) (deprecated)
   vizxdot()      -- show uml using xdot viewer. (recommended)
   tree()         -- generate tree figure
   viztree()      -- show tree figure ($RFSM_VIEWER) (deprecated)
   add_hook(func) -- add a function to be called after state changes (e.g. 'add_hook(pp)')
	 ]=])
end

boiler()
_fsm=rfsm.load(file)
ret, fsm = pcall(rfsm.init, _fsm)

if not ret or not fsm then
   print("rfsm-sim: failed to initialize fsm:", fsm)
   os.exit(1)
end

add_hook(showfqn)
add_hook(showeq)
dbg(false)
