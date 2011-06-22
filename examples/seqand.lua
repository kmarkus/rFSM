--- Sequential-AND state example
-- This simple fsm demonstrates the use of sequential AND states.

require "rfsm"
require "rfsm_ext"
require "fsmpp"

return rfsm.csta {
   dbg=fsmpp.gen_dbgcolor2("parent"),
   and_state = rfsm_ext.seqand {
      -- subfsm 1
      s1=rfsm.init(
	 rfsm.csta {
	    dbg=fsmpp.gen_dbgcolor2("subfsm1"),
	    s11=rfsm.sista{},
	    s12=rfsm.sista{},
	    rfsm.trans{src="initial", tgt="s11", },
	    rfsm.trans{src="s11", tgt="s12", events={"e_one"}},
	    rfsm.trans{src="s12", tgt="s11", events={"e_two"}},
	 }),

      -- subfsm 2
      s2=rfsm.init(
	 rfsm.csta {
	    dbg=fsmpp.gen_dbgcolor2("subfsm2"),
	    s21 = rfsm.sista {
	       doo = function(fsm)
			while true do
			   print("hi from s2 doo!")
			   rfsm.yield(true)
			end
		     end
	    },
	    rfsm.trans{src="initial", tgt="s21" },
	 }),
   },

   off = rfsm.sista{},
   rfsm.trans{src="initial", tgt="off"},
   rfsm.trans{src="off", tgt="and_state", events={"e_on"}},
   rfsm.trans{src="and_state", tgt="off", events={"e_off"}},
}