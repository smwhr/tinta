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

local elapsedTime = nil
function ink.resetElapsedTime()
    if playdate then
        playdate.resetElapsedTime()
    else
        elapsedTime = os.clock() * 1000
    end
end

function ink.getElapsedTime()
    if playdate then
        return playdate.getElapsedTime()*1000
    else
        return os.clock()*1000 - elapsedTime
    end
end

function ink.ContainsAny(t)
    for _,_ in pairs(t) do
        return true
    end
    return false
end

return ink