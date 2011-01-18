-- -*- lua -*-
require "rfsm"
require "fsmpp"
require "fsmuml"

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

function step()
   rfsm.step(fsm)
   pp()
end

print([=[

    available commands:
	    dbg(bool) -- enable/disable debug info
	    se(...)   -- send events
	    pp()      -- pretty print fsm
	    run()     -- run FSM
	    step()    -- step FSM
      ]=])