--
-- Useful code snips
-- some own ones, some collected from the lua wiki
--

local type, pairs, ipairs, setmetatable, getmetatable, assert, table, print, tostring, string, io, unpack, error =
   type, pairs, ipairs, setmetatable, getmetatable, assert, table, print, tostring, string, io, unpack, error

module('utils')

-- increment major on API breaks
-- increment minor on non breaking changes
VERSION=0.991

function append(car, ...)
   assert(type(car) == 'table')
   local new_array = {}

   for i,v in pairs(car) do
      table.insert(new_array, v)
   end
   for _, tab in ipairs({...}) do
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

   if type(tbl) ~= 'table' then return tostring(tbl) end

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

--- Wrap a long string.
-- source: http://lua-users.org/wiki/StringRecipes
-- @param str string to wrap
-- @param limit maximum line length
-- @param indent regular indentation
-- @param indent1 indentation of first line
function wrap(str, limit, indent, indent1)
   indent = indent or ""
   indent1 = indent1 or indent
   limit = limit or 72
   local here = 1-#indent1
   return indent1..str:gsub("(%s+)()(%S+)()",
			    function(sp, st, word, fi)
			       if fi-here > limit then
				  here = st - #indent
				  return "\n"..indent..word
			       end
			    end)
end


function pp(val)
   if type(val) == 'table' then print(tab2str(val))
   else print(val) end
end

function lpad(str, len, char, strlen)
   strlen = strlen or #str
   if char == nil then char = ' ' end
   return string.rep(char, len - strlen) .. str
end

function rpad(str, len, char, strlen)
   strlen = strlen or #str
   if char == nil then char = ' ' end
   return str .. string.rep(char, len - strlen)
end

-- Trim functions: http://lua-users.org/wiki/CommonFunctions
-- Licensed under the same terms as Lua itself.--DavidManura
function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))    -- from PiL2 20.4
end

-- remove leading whitespace from string.
function ltrim(s) return (s:gsub("^%s*", "")) end

-- remove trailing whitespace from string.
function rtrim(s)
   local n = #s
   while n > 0 and s:find("^%s", n) do n = n - 1 end
   return s:sub(1, n)
end

--- Strip ANSI color escape sequence from string.
-- @param str string
-- @return stripped string
-- @return number of replacements
function strip_ansi(str) return string.gsub(str, "\27%[%d+m", "") end

--- Convert string to string of fixed lenght.
-- Will either pad with whitespace if too short or will cut of tail if
-- too long. If dots is true add '...' to truncated string.
-- @param str string
-- @param len lenght to set to.
-- @param dots boolean, if true append dots to truncated strings.
-- @return processed string.
function strsetlen(str, len, dots)
   if string.len(str) > len and dots then
      return string.sub(str, 1, len - 4) .. "... "
   elseif string.len(str) > len then
      return string.sub(str, 1, len)
   else return rpad(str, len, ' ') end
end

function stderr(...)
   io.stderr:write(...)
   io.stderr:write("\n")
end

function stdout(...)
   print(...)
end

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

-- basename("aaa") -> "aaa"
-- basename("aaa.bbb.ccc") -> "ccc"
function basename(n)
   if not string.find(n, '[\\.]') then
      return n
   else
      local t = split(n, "[\\.]")
      return t[#t]
   end
end

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
   function __flatten(res, t)
      if type(t) == 'table' then
	 for k,v in ipairs(t) do __flatten(res, v) end
      else
	 res[#res+1] = t
      end
      return res
   end

   return __flatten({}, t)
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

function imap(f, tab)
   local newtab = {}
   if tab == nil then return newtab end
   for i,v in ipairs(tab) do
      local res = f(v,i)
      newtab[#newtab+1] = res
   end
   return newtab
end

function map(f, tab)
   local newtab = {}
   if tab == nil then return newtab end
   for i,v in pairs(tab) do
      local res = f(v,i)
      table.insert(newtab, res)
   end
   return newtab
end

function filter(f, tab)
   local newtab= {}
   if not tab then return newtab end
   for i,v in pairs(tab) do
      if f(v,i) then
	 table.insert(newtab, v)
      end
   end
   return newtab
end

function foreach(f, tab)
   if not tab then return end
   for i,v in pairs(tab) do f(v,i) end
end

function foldr(func, val, tab)
   if not tab then return val end
   for i,v in pairs(tab) do
      val = func(val, v)
   end
   return val
end

-- O' Scheme, where art thou?
-- turn operator into function
function AND(a, b) return a and b end

-- and which takes table
function andt(...)
   local res = true
   local tab = {...}
   for _,t in ipairs(tab) do
      res = res and foldr(AND, true, t)
   end
   return res
end

function eval(str)
   return assert(loadstring(str))()
end

-- compare two tables
function table_cmp(t1, t2)
   local function __cmp(t1, t2)
      -- t1 _and_ t2 are not tables
      if not (type(t1) == 'table' and type(t2) == 'table') then
	 if t1 == t2 then return true
	 else return false end
      elseif type(t1) == 'table' and type(t2) == 'table' then
	 if #t1 ~= #t2 then return false
	 else
	    -- iterate over all keys and compare against k's keys
	    for k,v in pairs(t1) do
	       if not __cmp(t1[k], t2[k]) then
		  return false
	       end
	    end
	    return true
	 end
      else -- t1 and t2 are not of the same type
	 return false
      end
   end
   return __cmp(t1,t2) and __cmp(t2,t1)
end

function table_has(t, x)
   for _,e in ipairs(t) do
      if e==x then return true end
   end
   return false
end

--- Return a new table with unique elements.
function table_unique(t)
   local res = {}
   for i,v in ipairs(t) do
      if not table_has(res, v) then res[#res+1]=v end
   end
   return res
end

--- Convert arguments list into key-value pairs.
-- The return table is indexable by parameters (i.e. ["-p"]) and the
-- value is an array of zero to many option parameters.
-- @param standard Lua argument table
-- @return key-value table
function proc_args(args)
   local function is_opt(s) return string.sub(s, 1, 1) == '-' end
   local res = { [0]={} }
   local last_key = 0
   for i=1,#args do
      if is_opt(args[i]) then -- new key
	 last_key = args[i]
	 res[last_key] = {}
      else -- option parameter, append to existing tab
	 local list = res[last_key]
	 list[#list+1] = args[i]
      end
   end
   return res
end

--- Simple advice functionality
-- If oldfun is not nil then returns a closure that invokes both
-- oldfun and newfun. If newfun is called before or after oldfun
-- depends on the where parameter, that can take the values of
-- 'before' or 'after'.
-- If oldfun is nil, newfun is returned.
-- @param where string <code>before</code>' or <code>after</code>
-- @param oldfun (can be nil)
-- @param newfunc
function advise(where, oldfun, newfun)
   assert(where == 'before' or where == 'after',
	  "advise: Invalid value " .. tostring(where) .. " for where")

   if oldfun == nil then return newfun end

   if where == 'before' then
      return function (...) newfun(...); oldfun(...); end
   else
      return function (...) oldfun(...); newfun(...); end
   end
end

--- Check wether a file exists.
-- @param fn filename to check.
-- @return true or false
function file_exists(fn)
   local f=io.open(fn);
   if f then io.close(f); return true end
   return false
end

--- From Book  "Lua programming gems", Chapter 2, pg. 26.
function memoize (f)
   local mem = {} 			-- memoizing table
   setmetatable(mem, {__mode = "kv"}) 	-- make it weak
   return function (x) 			-- new version of ’f’, with memoizing
	     local r = mem[x]
	     if r == nil then 	-- no previous result?
		r = f(x) 	-- calls original function
		mem[x] = r 	-- store result for reuse
	     end
	     return r
	  end
end

--- call thunk every s+ns seconds.
function gen_do_every(s, ns, thunk, gettime)
   local next = { sec=0, nsec=0 }
   local cur = { sec=0, nsec=0 }
   local inc = { sec=s, nsec=ns }

   return function()
	     cur.sec, cur.nsec = gettime()

	     if time.cmp(cur, next) == 1 then
		thunk()
		next.sec, next.nsec = time.add(cur, inc)
	     end
	  end
end

--- Expand parameters in string template.
-- @param tpl string containing $NAME parameters.
-- @param params table of NAME=value pairs for substitution.
-- @param warn optionally warn if there are nonexpanded parameters.
-- @return new string
-- @return number of unexpanded parameters
function expand(tpl, params, warn)
   if warn==nil then warn=true end
   local unexp = 0

   -- expand
   for name,val in pairs(params) do tpl=string.gsub(tpl, "%$"..name, val) end

   -- check for unexpanded
   local _,_,res= string.find(tpl, "%$([%a%d_]+)")
   if res then
      if warn then print("expand: warning, no param for variable $" .. res) end
      unexp = unexp + 1
   end

   return tpl, unexp
end
