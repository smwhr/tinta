local ink = { }

function ink.asOrNil(item, Class)
    if Class == nil then error("Trying to as nil") end
    if item == nil then return nil end
    if item:is(Class) then 
        return item
    else
        return nil
    end
end

function ink.isInteger(val)
    if tonumber(val) == nil then return false end
    local e,f = math.modf(tonumber(val))
    return f == 0
end

return ink