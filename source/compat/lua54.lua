local compat = {}

function compat.band(a, b)
    return a & b 
end

function compat.bor(a, b)
    return a | b 
end


return compat