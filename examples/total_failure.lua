-- an *extremly* bug ridden fsm

return rfsm.csta{
   a=rfsm.sista{
      entry=function() error("failing in entry!") end,
      doo=function() error("failing in doo!") end,
      exit=function() error("failing in exit!") end,
   },

   b=rfsm.sista{
      entry=function() print("everything ok now!") end,
   },

   rfsm.trans{src='initial', tgt='a', 
	      effect=function() error("effect is even buggier") end },
   
   rfsm.trans{src='a', tgt='b', guard=function() error("guard is buggy too") end,
},
}