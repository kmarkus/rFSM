-- useful functions

local type, pairs, ipairs, setmetatable, getmetatable, assert, table, print, tostring, string =
   type, pairs, ipairs, setmetatable, getmetatable, assert, table, print, tostring, string

module('utils')

function append(car, ...)
   assert(type(car) == 'table')
   local new_array = {}
   
   for i,v in pairs(car) do
      table.insert(new_array, v)
   end
   for _, tab in ipairs(arg) do
      for k,v in pairs(tab) do
	 table.insert(new_array, v)
      end
   end
   return new_array
end

function tab2str( tbl )
   local function val_to_str ( v )
      if "string" == type( v ) then
	 v = string.gsub( v, "\n", "\\n" )
	 if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
	    return "'" .. v .. "'"
	 end
	 return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
      else
	 return "table" == type( v ) and tab2str( v ) or tostring( v )
      end
   end

   local function key_to_str ( k )
      if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
	 return k
      else
	 return "[" .. val_to_str( k ) .. "]"
      end
   end

   local result, done = {}, {}
   for k, v in ipairs( tbl ) do
      table.insert( result, val_to_str( v ) )
      done[ k ] = true
   end
   for k, v in pairs( tbl ) do
      if not done[ k ] then
	 table.insert( result, key_to_str( k ) .. "=" .. val_to_str(v))
      end
   end
   return "{" .. table.concat( result, "," ) .. "}"
end

function rpad(str, len, char)
   if char == nil then char = ' ' end
   return string.rep(char, len - #str) .. str
end

function lpad(str, len, char) 
   if char == nil then char = ' ' end
   return str .. string.rep(char, len - #str)
end

function car(tab)
   return tab[1]
end

function cdr(tab)
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

-- flatten
-- from nmap listops
-- see http://nmap.org/book/man-legal.html
function flatten(l)
    local function flat(r, t)
    	for i, v in ipairs(t) do
    		if(type(v) == 'table') then
    			flat(r, v)
    		else
    			table.insert(r, v)
    		end
    	end
    	return r
    end
    return flat({}, l)
end

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
   if tab == nil then return newtab end
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
