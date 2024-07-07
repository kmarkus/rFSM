--- Sequential-AND state example
-- This simple fsm demonstrates the use of sequential AND states.

local rfsm = require("rfsm")
local rfsm_ext = require("rfsm_ext")
local rfsmpp = require("rfsmpp")

local state, conn, trans = rfsm.state, rfsm.conn, rfsm.trans

return state {
   dbg=rfsmpp.gen_dbgcolor("parent"),
   and_state = rfsm_ext.seqand {
      seqanddbg=true,

      -- define the order in which the subfsm shall be step'ed. The
      -- list must not be exhaustive; all not mentioned states will be
      -- after the ones listed in 'order' executed in arbitrary
      -- ordering.
      order = {'s2', 's1'},

      entry=function() print("entering seqand") end,
      exit=function() print("exiting seqand") end,

      -- subfsm 1
      s1=rfsm.init(
	 state {
	    dbg=rfsmpp.gen_dbgcolor("subfsm1"),
	    s11=state{},
	    s12=state{},
	    trans{src="initial", tgt="s11", },
	    trans{src="s11", tgt="s12", events={"e_one"}},
	    trans{src="s12", tgt="s11", events={"e_two"}},
	 }),

      -- subfsm 2
      s2=rfsm.init(
	 state {
	    dbg=rfsmpp.gen_dbgcolor("subfsm2"),
	    s21 = state {
	       doo = function(fsm)
			while true do
			   print("hi from s2 doo!")
			   rfsm.yield(true)
			end
		     end
	    },
	    trans{src="initial", tgt="s21" },
	 }),
   },

   off = state{},
   trans{src="initial", tgt="off"},
   trans{src="off", tgt="and_state", events={"e_on"}},
   trans{src="and_state", tgt="off", events={"e_off"}},
}
