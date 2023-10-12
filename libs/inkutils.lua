local ink = { }

function ink.asOrNil(item, Class)
    if item == nil then return nil end
    if item:is(Class) then 
        return item
    else
        return nil
    end
end

return ink