-- -*- lua -*-
require "rfsm"
require "fsmpp"
require "fsm2uml"
require "fsm2tree"

if arg and #arg < 1 then
   print("usage: run <fsmfile>")
   os.exit(1)
end

file = arg[1]

_fsm=dofile(file)
fsm=rfsm.init(_fsm)

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
function dbg(on_off)
   if not on_off then fsm.dbg=function(...) return end
   else fsm.dbg=fsmpp.gen_dbgcolor2(file) end
end

-- operational
function se(...)
   rfsm.send_events(fsm, unpack(arg)) 
end

function ser(...)
   rfsm.send_events(fsm, unpack(arg))
   rfsm.run(fsm)
   run_hooks()
end

function run()
   rfsm.run(fsm);
   run_hooks()
end

function step(n)
   n = n or 1
   rfsm.step(fsm, n)
   run_hooks()
end

-- visualisation
function pp()
   print(fsmpp.fsm2str(fsm))
end

function uml()
   fsm2uml.fsm2uml(fsm, "png", tmpdir .. "rfsm-uml-tmp.png")
end

function tree()
   fsm2tree.fsm2tree(fsm, "png",  tmpdir .. "rfsm-tree-tmp.png")
end

function vizuml()
   local viewer = os.getenv("RFSM_VIEWER") or "iceweasel"
   os.execute(viewer .. " " ..  tmpdir .. "rfsm-uml-tmp.png" .. "&")
end

function viztree()
   local viewer = os.getenv("RFSM_VIEWER") or "iceweasel"
   os.execute(viewer .. " " .. tmpdir .. "rfsm-tree-tmp.png" .. "&")
end

print([=[
    available commands:
	    dbg(bool)      -- enable/disable debug info
	    se(...)        -- send events
	    ser(...)       -- send events and run()
	    run()          -- run FSM
	    step()         -- step FSM
	    pp()           -- pretty print fsm
	    uml()          -- generate uml figure
	    vizuml()       -- show uml figure ($RFSM_VIEWER)
	    tree()         -- generate tree figure
	    viztree()      -- show tree figure ($RFSM_VIEWER)
	    add_hook(func) -- add a function to be called after state changes (e.g. 'add_hook(pp)')
      ]=])

add_hook(pp)
add_hook(uml)
add_hook(tree)

dbg(true)