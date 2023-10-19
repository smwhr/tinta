local lookup = {}
function _dump(o)
   local address = tostring(o)
   if lookup[address] then
      return address
   end
   if type(o) == 'table' then
      lookup[address] = address
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. _dump(v) .. ','
       end
       return s .. '} '
   elseif address == "Container" then
      if o.name then
         s = s .. "Containere(" .. o.name .. ")"
      else
         s = s .. "Containere"
      end
      return s .. "[" .. _dump(o.content) .. "]"
   else
       return tostring(o)
   end
end

function dump(o)
   lookup = {}
   return _dump(o)
end

return dump