--
-- composite tests transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("fsm2uml")
require("fsmtesting")
require("fsmpprint")
require("utils")

local function test_doo(text)
   return function ()
	     for i = 1,3 do
		print(text, i)
		os.execute("sleep 1")
		coroutine.yield()
	     end
	  end
end

parallel_tpl = rfsm.csta:new{
   dbg = fsmpprint.dbgcolor,

   -- a parallel state: all composite states within are executed in parallel
   homing = rfsm.psta:new{ 

      -- homing axis1 composite state
      ax0_csta = rfsm.csta:new {
	 entry=function() print "entering ax0 csta" end,
	 exit=function() print "exiting ax0 csta" end,
	 ax0 = rfsm.sista:new{ doo=test_doo("homing axis0") },
	 rfsm.trans:new { src='initial', tgt='ax0' },
	 rfsm.trans:new { src='ax0', tgt='final' },
      },

      -- homing axis1 composite state
      ax1_csta = rfsm.csta:new {
	 entry=function() print "entering ax1 csta" end,
	 exit=function() print "exiting ax1 csta" end,
	 ax1 = rfsm.sista:new{ doo=test_doo("homing axis1") },
	 rfsm.trans:new { src='initial', tgt='ax1' },
	 rfsm.trans:new { src='ax1', tgt='final' },
      },

      -- homing axis2 composite state
      ax2_csta = rfsm.csta:new {
	 entry=function() print "entering ax2 csta" end,
	 exit=function() print "exiting ax2 csta" end,
	 ax2 = rfsm.sista:new{ doo=test_doo("homing axis2") },
	 rfsm.trans:new { src='initial', tgt='ax2' },
	 rfsm.trans:new { src='ax2', tgt='final' },
      }
   },

   rfsm.trans:new{ src='initial', tgt='homing' },
   rfsm.trans:new{ src='homing', tgt='final' }
}

fsm = rfsm.init(parallel_tpl, "parallel_test")

fsm2uml.fsm2uml(fsm, "png", "parallel.png")

rfsm.step(fsm)
print("step 2")
rfsm.step(fsm)
