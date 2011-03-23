--
-- simple example to illustrate the use of gen_monitor_state.
--

require("rfsm_ext")

--- generate a function which ramdomly returns true n of m times
-- @param n
-- @param m
function gen_sometimes_true(n, m)
   math.randomseed( os.time() )
   return function ()
	     if n > math.random(0,m) then
		return true
	     else
		return false
	     end
	  end
end

-- generate a function which prints 'this'
-- @param this
function gen_print_this(this)
   return function() print(this) end
end

-- a table of event=monitorfunction pairs
mon={
   event_1 = gen_sometimes_true(1, 1000000),
   event_5 = gen_sometimes_true(5, 1000000),
   event_10 = gen_sometimes_true(10, 1000000),
}

return rfsm.csta:new {

   monitoring = rfsm_ext.gen_monitor_state{montab=mon, break_first=true},

   rfsm.trans:new{src='.monitoring', tgt='.monitoring', events={'event_1'}, effect=gen_print_this("event_1")},
   rfsm.trans:new{src='.monitoring', tgt='.monitoring', events={'event_5'}, effect=gen_print_this("event_5")},
   rfsm.trans:new{src='.monitoring', tgt='.monitoring', events={'event_10'}, effect=gen_print_this("event_10")},
   rfsm.trans:new{src='initial', tgt='.monitoring'},

}