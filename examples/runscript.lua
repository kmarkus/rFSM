require("rfsm")

-- load state machine model and initalize it
fsm_model=dofile("examples/hello_world.lua")
fsm = rfsm.init(fsm_model)

-- run it, run returns when there is nothing left to do otherwise never
rfsm.run(fsm)

-- send some event to the internal queue
rfsm.send_events(fsm, "e_restart", "e_this", "e_that")

-- opposed to run this will advance the fsm (at most) twice
rfsm.step(fsm,2)
