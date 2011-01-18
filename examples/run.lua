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

function dbg(on_off)
   if not on_off then fsm.dbg=function(...) return end
   else fsm.dbg=fsmpp.gen_dbgcolor2(file) end
end

function se(...)
   rfsm.send_events(fsm, unpack(arg))
end

function pp()
   print(fsmpp.fsm2str(fsm))
end

function run()
   rfsm.run(fsm)
   pp()
end

function step(n)
   n = n or 1
   rfsm.step(fsm, n)
   pp()
end

function uml()
   local outfile = "/tmp/" .. file .. "-uml.png"
   local viewer = os.getenv("RFSM_VIEWER") or "iceweasel"
   fsm2uml.fsm2uml(fsm, "png", outfile)
   os.execute(viewer .. " " .. outfile)
end

function tree()
   local outfile = "/tmp/" .. file .. "-tree.png"
   local viewer = os.getenv("RFSM_VIEWER") or "iceweasel"
   fsm2tree.fsm2tree(fsm, "png", outfile)
   os.execute(viewer .. " " .. outfile)
end

print([=[
    available commands:
	    dbg(bool) -- enable/disable debug info
	    se(...)   -- send events
	    run()     -- run FSM
	    step()    -- step FSM
	    pp()      -- pretty print fsm
	    uml()     -- pretty print fsm as uml (export RFSM_VIEWER)
	    tree()    -- pretty print fsm as tree (export RFSM_VIEWER)
      ]=])