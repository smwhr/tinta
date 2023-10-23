local InkList = classic:extend()

function InkList:new()
    self._inner = {}
    self.origins = nil
    self._originNames = {}
end


function InkList:FromInkList(otherList)
    local newList = InkList()
    newList._inner = lume.clone(otherList._inner)

    local originNames = otherList:originNames()
    if originNames ~= nil then
        newList._originNames = lume.clone(originNames)
    end
    if otherList.origins ~= nil then
        newList.origins = lume.clone(otherList.origins)
    end
    return newList
end

function InkList:FromOriginListName(singleOriginListName, originStory)
    local newList = InkList()
    newList:SetInitialOriginName(singleOriginListName)
    local def = originStory.listDefinitions:TryListGetDefinition(singleOriginListName, nil)
    if def.exists then
        self.origins = {def.result}
    else
        error("InkList origin could not be found in story when constructing new list: " .. singleOriginListName)
    end
    return newList
end

function InkList:FromSingleKeyValueItem(singleElement)
    local newList = InkList()
    newList:Add(singleElement.Key, singleElement.Value)
    return newList
end

function InkList:originNames()
    if self:Count() > 0 then
        self._originNames = {} 

        for key,_ in pairs(self._inner) do
            local item = ListItem:fromSerializedKey(key)
            table.insert(self._originNames, item.originName)
        end
    end

    return self._originNames
end

function InkList:SetInitialOriginName(initialOriginName)
    self._originNames = {initialOriginName}
end

function InkList:SetInitialOriginNames(initialOriginNames)
    if initialOriginNames == nil then self._originNames = nil 
    else self._originNames = lume.clone(initialOriginNames)
    end
end

function InkList:maxItem()
    local max = {Key= ListItem:Null(), Value=0}
    for key, value in pairs(self._inner) do
        local item = ListItem:fromSerializedKey(key)
        if max.Key:isNull() or value > max.Value then
            max = { Key = item, Value = value}
        end
    end
    return max
end

function InkList:minItem()
    local min = {Key= ListItem:Null(), Value=0}
    for key, value in pairs(self._inner) do
        local item = ListItem:fromSerializedKey(key)
        if min.Key:isNull() or value < min.Value then
            min = { Key = item, Value = value}
        end
    end
    return min
end

function InkList:orderedItems()
    local ordered = {}
    for key, value in pairs(self._inner) do
        local item = ListItem:fromSerializedKey(key)
        table.insert(ordered, {Key=item, Value=value})
    end

    table.sort(
        ordered, function(x, y)
            if x.Value == y.Value then
                return x.Key.originName > x.Key.originName
            else
                return x.Value < y.Value 
            end
        end
    )
    return ordered
end

function InkList:inverse()
    local list = InkList()
    if self.origins ~= nil then
        for _,origin in pairs(self.origins) do
            for key, value in pairs(origin:items()) do
                local item = ListItem:fromSerializedKey(key)
                if not self:ContainsKey(item) then
                    list:Add(item, value)
                end
            end
        end
    end
    return list
end

function InkList:all()
    local list = InkList()
    if self.origins ~= nil then
        for _,origin in pairs(self.origins) do
            for key, value in pairs(origin:items()) do
                local item = ListItem:fromSerializedKey(key)
                list._inner[item:serialized()] = value
            end
        end
    end
    return list
end

function InkList:Union(otherList)
    local union = InkList:FromInkList(self)
    for key, value in pairs(otherList._inner) do
        union._inner[key] = value
    end
    return union
end

function InkList:Intersect(otherList)
    local intersection = InkList()
    for key, value in pairs(self._inner) do
        if otherList._inner[key] ~= nil then
            intersection._inner[key] = value
        end
    end
    return intersection
end

function InkList:HasIntersection(otherList)
    for key, value in pairs(self._inner) do
        if otherList._inner[key] ~= nil then
            return true
        end
    end
    return false
end

function InkList:Without(listToRemove)
    local result = InkList:FromInkList(self)
    for key, _ in pairs(listToRemove._inner) do
        result._inner[key] = nil
    end
    return result
end

function InkList:Contains(what)
    if type(what) == "string" then
        return self:ContainsItemNamed(what)
    end
    local otherList = what
    if lume.count(otherList._inner) == 0 or lume.count(self._inner) == 0 then return false end
    for key, _ in pairs(otherList._inner) do
        if self._inner[key] == nil then
            return false
        end
    end
    return true
end

function InkList:GreaterThan(otherList)
    if self:Count() == 0 then return false end
    if otherList:Count() == 0 then return true end

    return self:minItem().Value > otherList:minItem().Value
end

function InkList:GreaterThanOrEquals(otherList)
    if self:Count() == 0 then return false end
    if otherList:Count() == 0 then return true end

    return self:minItem().Value >= otherList:minItem().Value
       and self:maxItem().Value >= otherList:maxItem().Value
end

function InkList:LessThan(otherList)
    if otherList:Count() == 0 then return false end
    if self:Count() == 0 then return true end

    return self:maxItem().Value > otherList:maxItem().Value
end

function InkList:LessThanOrEquals(otherList)
    if otherList:Count() == 0 then return false end
    if self:Count() == 0 then return true end

    return self:maxItem().Value <= otherList:maxItem().Value
       and self:minItem().Value <= otherList:minItem().Value
end

function InkList:MaxAsList()
    if self:Count() > 0 then 
        return InkList:FromSingleKeyValueItem(self:maxItem())
    else
        return InkList()
    end
end

function InkList:MinAsList()
    if self:Count() > 0 then 
        return InkList:FromSingleKeyValueItem(self:minItem())
    else
        return InkList()
    end
end

function InkList:ListWithSubRange(minBound, maxBound)
    if self:Count() == 0 then
        return InkList()
    end
    local ordered = self:orderedItems()
    local minValue = 0
    local maxValue = 2^32
    
    if inkutils.isInteger(minBound) then
        minValue = minBound
    elseif minBound:is(InkList) and minBound:Count() > 0 then
        minValue = minBound:minItem().Value
    end

    if inkutils.isInteger(maxBound) then
        maxValue = maxBound
    elseif maxBound:is(InkList) and maxBound:Count() > 0 then
        maxValue = maxBound:maxItem().Value
    end

    local subList = InkList()
    subList:SetInitialOriginNames(self:originNames())
    for _,item in ipairs(ordered) do
        if item.Value >= minValue and item.Value <= maxValue then
            subList:Add(item.Key, item.Value)
        end
    end
    return subList
end

function InkList:Equals(otherInkList)

    if not otherInkList:is(InkList) then 
        return false 
    end
    if self:Count() ~= otherInkList:Count() then 
        return false 
    end

    for key,_ in pairs(self._inner) do
        if otherInkList._inner[key] == nil then 
            return false 
        end
    end
    return true
end

function InkList:ContainsItemNamed(itemName)
    for k,_ in pairs(self._inner) do
        local item = ListItem:fromSerializedKey(key)
        if item.itemName == itemName then return true end
    end
    return false
end

function InkList:ContainsKey(key)
    return self._inner[key:serialized()] ~= nil
end

function InkList:Add(key, value)
    local serializedKey = key:serialized()
    
    if self._inner[serializedKey] ~= nil then
        error("The Map already contains an entry for " .. serializedKey)
    end
    
    self._inner[serializedKey] = value
end

function InkList:Remove(key)
    local ret = self._inner[key:serialized()] ~= nil
    self._inner[key:serialized()] = nil
    return ret
end

function InkList:Count()
    return #lume.keys(self._inner)
end

function InkList:originOfMaxItem()
    if self.origins == nil then return nil end

    local maxOriginName = self:maxItem().Key.originName
    
    for _, origin in pairs(self.origins) do
        if origin.name == maxOriginName then
            return origin
        end
    end
    return nil
end

function InkList:__tostring()
    local ordered = self:orderedItems()
    local sb = {}
    for i = 1, #ordered do
        if i > 1 then
            table.insert(sb, ", ")
        end

        local item = ordered[i].Key
        table.insert(sb, item.itemName)
    end
    return table.concat(sb)
end

return InkList