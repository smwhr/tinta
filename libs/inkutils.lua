local ink = { }

function ink.asOrNil(item, Class)
    if item:is(Class) then 
        return item
    else
        return nil
    end
end

return ink