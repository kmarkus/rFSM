
-- The homing statemachine

function home_axis_step(num)
   while not axis_home(num) do
      print('homing axis step ' .. x)
      coroutine.yield()
   end
end

homing_arm = {
   {
      name = 'cs_home_axis1',
      initial = 's_home_axis1',
      states = { {
		    name = 's_home_axis1',
		    doo = function () home_axis_step(1) end,
		    transitions	= { { event='e_completion', target='final' } } } } },
   {
      name = 'cs_home_axis2',
      initial = 's_home_axis2',
      states = { {
		    name = 's_home_axis2',
		    doo = function () home_axis_step(2) end,
		    transitions	= { { event='e_completion', target='final' } } } } },
   {
      name =	'cs_home_axis3',
      initial	= 's_home_axis3',
      states	= { 
	 {
	    name	= 's_home_axis3',
	    doo		= function () home_axis_step(3) end,
	    transitions	= { { event='e_completion', target='final' } } } } },
   {
      name	= 'cs_home_axis4',
      initial	= 's_home_axis4',
      states	= { 
	 {
	    name	= 's_home_axis4',
	    doo		= function () home_axis_step(4) end,
	    transitions	= { { event='e_completion', target='final' } } } } },
   {
      name	= 'cs_home_axis5',
      initial	= 's_home_axis5',
      states	= {
	 {
	    name	= 's_home_axis5',
	    doo		= function () home_axis_step(5) end,
	    transitions	= { { event='e_completion', target='final' } } } } }, 
   {
      name	= 'cs_home_axis6',
      initial	= 's_home_axis6',
      states	= { 
	 {
	    name	= 's_home_axis6',
	    doo		= function () home_axis_step(6) end,
	    transitions	= { { event='e_completion', target='final' } } } } },
}


print_tab(homing_arm, '\t', 0)
