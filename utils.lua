-- useful functions

local type, pairs, ipairs, setmetatable, getmetatable, assert, table, print =
   type, pairs, ipairs, setmetatable, getmetatable, assert, table, print

module('utils')

function append(car, ...)
   car = car or {}
   local new_array = {}
   
   for i,v in ipairs(car) do
      table.insert(new_array, v)
   end
   for _, tab in ipairs(arg) do
      for i,v in ipairs(tab) do
	 table.insert(new_array, v)
      end
   end
   return new_array
end

--(define (flatten l)
-- (cond ((null? l) ())
--((list? l)
--   (append (flatten (car l)) (flatten (cdr l))))
--  (else (list l))))
function car(tab)
   return tab[1]
end

function cdr(tab)
   local new_array = {}
   for i = 2, table.getn(tab) do
      table.insert(new_array, tab[i])
   end
   return new_array
end

function cons(car, cdr)
   local new_array = {car}
  for _,v in cdr do
     table.insert(new_array, v)
  end
  return new_array
end

function flatten(t)
   print("flattening", t)
   if not t then
      return {}
   end
   
   if type(t) ~= 'table' then
      return {t}
   else
      if #t == 0 then return {} end
      return append(flatten(car(t), flatten(cdr(t))))
   end
end

table.foreach(
   flatten( {1,2,3,{11,22,{111,222,333}},4} ), 
   print)

function deepcopy(object)
   local lookup_table = {}
   local function _copy(object)
      if type(object) ~= "table" then
            return object
      elseif lookup_table[object] then
	 return lookup_table[object]
      end
      local new_table = {}
      lookup_table[object] = new_table
      for index, value in pairs(object) do
	 new_table[_copy(index)] = _copy(value)
      end
      return setmetatable(new_table, getmetatable(object))
   end
   return _copy(object)
end

function map(f, tab)
   local newtab = {}
   if not tab then return newtab end
   for i,v in pairs(tab) do
      res = f(v)
      table.insert(newtab, res)
   end
   return newtab
end

function filter(f, tab)
   local newtab= {}
   if not tab then return newtab end
   for i,v in pairs(tab) do
      if f(v) then
	 table.insert(newtab, v)
      end
   end
   return newtab
end

function foldr(func, val, tab)
   if not tab then return val end
   for i,v in pairs(tab) do
      val = func(val, v)
   end
   return val
end

function AND(a, b)
   return a and b
end

function eval(str)
   return assert(loadstring(str))()
end
