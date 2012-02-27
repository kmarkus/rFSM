--- Sequential-AND state example
-- This simple fsm demonstrates the use of sequential AND states.

require "rfsm"
require "rfsm_ext"
require "rfsmpp"

return rfsm.csta {
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
	 rfsm.csta {
	    dbg=rfsmpp.gen_dbgcolor("subfsm1"),
	    s11=rfsm.sista{},
	    s12=rfsm.sista{},
	    rfsm.trans{src="initial", tgt="s11", },
	    rfsm.trans{src="s11", tgt="s12", events={"e_one"}},
	    rfsm.trans{src="s12", tgt="s11", events={"e_two"}},
	 }),

      -- subfsm 2
      s2=rfsm.init(
	 rfsm.csta {
	    dbg=rfsmpp.gen_dbgcolor("subfsm2"),
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