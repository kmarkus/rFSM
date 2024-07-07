local rfsm = require("rfsm")

return rfsm.csta{
   busy = rfsm.sista{
      doo=function()
	     for i=1,8 do
		foo(i,i*i,i*i*i)
		rfsm.yield()
	     end
	  end
   },
   rfsm.trans{ src='initial', tgt='busy'}
}
