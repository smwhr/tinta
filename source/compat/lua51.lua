local compat = {}


OR, XOR, AND = 1, 3, 4

function bitoper(a, b, oper)
   local r, m, s = 0, 2^31
   repeat
      s,a,b = a+b+m, a%m, b%m
      r,m = r + m*oper%(s-a-b), m/2
   until m < 1
   return r
end

function compat.band(a, b)
    return bitoper(a,b, AND)
end

function compat.bor(a, b)
    return bitoper(a,b, OR)
end


return compat