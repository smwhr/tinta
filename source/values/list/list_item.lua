local ListItem = classic:extend()

function ListItem:new(originName, itemName)
    self.originName = originName
    self.itemName = itemName
end

function ListItem:FromString(fullName)
    local parts = lume.split(fullName, ".")
    return ListItem(parts[1], parts[2])
end

function ListItem:Null()
    return ListItem(nil, nil)
end

function ListItem:isNull()
    return self.originName == nil and self.itemName == nil
end

function ListItem:fullName()
    local origin = "?"
    if self.originName ~= nil then
        origin = self.originName
    end
    return origin .. "." .. self.itemName
end

function ListItem:Copy()
    return ListItem(self.originName, self.itemName)
end

function ListItem:serialized()
    return "listitem|"..self.originName.."|"..self.itemName
end

function ListItem:fromSerializedKey(serialized)
    local parts = lume.split(serialized, "|")
    if parts[1] ~= "listitem" then
        return ListItem:Null()
    end

    return ListItem(parts[2], parts[3])

end

function ListItem:__tostring()
    return "ListItem"
end

return ListItem