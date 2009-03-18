function pp_table(t)
   for i,v in pairs(t) do
      print(i,v)
   end
end

function eval(str)
   return assert(loadstring(str))()
end

function step(statemachine)
   return true;
end

function send(sm)
end

function run(sm)
end


-- sample statemachine
fsm = {
   states = {
      { 
	 name = "on",
	 entry = "print('entry on')", 
	 doo = "print('inside on do')", 
	 exit = "print('inside on exit')",
	 transitions = { { event="on-button",
			   target="on" } }
      } {
	 name = "off",
	 entry = "print('entry on')", 
	 doo = "print('inside on do')", 
	 exit = "print('inside on exit')",
	 transitions = { { event="on-button",
			   target="on" } }
} } }

print("printing table:")
pp_table(a)

eval(a.doo)

pp_table(a.transitions)
