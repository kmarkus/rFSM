--
-- composite tests transitions
--

package.path = package.path .. ';../?.lua'

require("rtfsm")
require("fsm2uml")
require("fsmdbg")
require("utils")

local function printer_gen(s)
   return function (...) print(s, unpack(arg)) end
end

local function test_doo(text)
   return function ()
	     for i = 1,5 do
		print(text, i)
		os.execute("sleep 1")
		coroutine.yield()
	     end
	  end
end

parallel_tpl = rtfsm.csta:new{
   dbg = printer_gen("DBG:"),

   -- a parallel state: all composite states within are executed in parallel
   homing = rtfsm.psta:new{ 

      -- homing axis1 composite state
      ax0_csta = rtfsm.csta:new {
	 entry=function() print "entering ax0 csta" end,
	 exit=function() print "exiting ax0 csta" end,
	 ax0 = rtfsm.sista:new{ doo=test_doo("homing axis0") },
	 rtfsm.trans:new { src='initial', tgt='ax0' },
	 rtfsm.trans:new { src='ax0', tgt='final' },
      },

      -- homing axis1 composite state
      ax1_csta = rtfsm.csta:new {
	 entry=function() print "entering ax1 csta" end,
	 exit=function() print "exiting ax1 csta" end,
	 ax1 = rtfsm.sista:new{ doo=test_doo("homing axis1") },
	 rtfsm.trans:new { src='initial', tgt='ax1' },
	 rtfsm.trans:new { src='ax1', tgt='final' },
      },

      -- homing axis2 composite state
      ax2_csta = rtfsm.csta:new {
	 entry=function() print "entering ax2 csta" end,
	 exit=function() print "exiting ax2 csta" end,
	 ax2 = rtfsm.sista:new{ doo=test_doo("homing axis2") },
	 rtfsm.trans:new { src='initial', tgt='ax2' },
	 rtfsm.trans:new { src='ax2', tgt='final' },
      }
   },

   rtfsm.trans:new{ src='initial', tgt='homing' },
   rtfsm.trans:new{ src='homing', tgt='final' }
}

fsm = rtfsm.init(parallel_tpl, "parallel_test")

fsm2uml.fsm2uml(fsm, "png", "parallel.png")

rtfsm.step(fsm)
