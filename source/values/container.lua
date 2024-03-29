local CountFlags = {
    Visits = 1,
    Turns = 2,
    CountStartOnly = 4,
}

local Container = classic:extend()


function Container:new()
    self.name = nil
    self.content = {}
    self.namedContent = {}
    
    self.visitsShouldBeCounted = false
    self.turnIndexShouldBeCounted = false
    self.countingAtStartOnly = false
end

function Container:AddContent(contentOrList)
    if lume.isarray(contentOrList) then
        for _, c in ipairs(contentOrList) do
            self:AddContent(c)
        end
    else
        local contentObj = contentOrList
        
        table.insert(self.content, contentObj)

        contentObj.parent = self

        self:TryAddNamedContent(contentObj)
    end
end

function Container:TryAddNamedContent(contentObj)
    if contentObj.name ~= nil and contentObj:is(Container) then
        self:AddToNamedContentOnly(contentObj)
    end
end

function Container:ContentAtPath(path, partialStart, partialEnd)
    partialStart = partialStart or 1
    partialEnd = partialEnd or path:length()
    local result = SearchResult()
    result.approximate = false

    local currentContainer = self
    local currentObj = self

    for i = partialStart, partialEnd do
        local comp = path.components[i]
        if currentContainer == nil then
            result.approximate = true
            break
        end

        local foundObj = currentContainer:ContentWithPathComponent(comp)

        if foundObj == nil then
            result.approximate = true
            break
        end

        currentObj = foundObj
        currentContainer = inkutils.asOrNil(foundObj, Container)
        
    end
    result.obj = currentObj
    return result
end

function Container:ContentWithPathComponent(component)
    if component:isIndex() then
        if component.index >= 0 or component.index < #self.content then
            return self.content[component.index + 1]
        else
            return nil
        end
    elseif component:isParent() then
        return self.parent
    else
        local foundContent = self.namedContent[component.name]
        if foundContent == nil then
            return nil
        end
        return foundContent
    end
end

function Container:namedOnlyContent()
    local namedOnlyContentDict = {}

    for key, inkObj in ipairs(self.namedContent) do
        namedOnlyContentDict[key] = inkObj
    end

    for _,c in ipairs(self.content) do
        if c.name ~= nil and c:is(Container) then
            namedOnlyContentDict[c.name] = nil
        end
    end

    if #namedOnlyContentDict == 0 then return nil end
    return namedOnlyContentDict
end

function Container:setNamedOnlyContent(value)
    local existingNamedOnly = self:namedOnlyContent()

    if existingNamedOnly ~= nil then
        for k,_ in ipairs(existingNamedOnly) do
            self.namedContent[k] = nil
        end
    end
    
    if value == nil then return end

    for _,val in pairs(value) do
        if val.name ~= nil then
            self:AddToNamedContentOnly(val)
        end
    end
end

function Container:AddToNamedContentOnly(namedContentObj)
    namedContentObj.parent = self
    self.namedContent[namedContentObj.name] = namedContentObj
end

function Container:setCountFlags(value)
    if compat.band(value, CountFlags.Visits) > 0 then
        self.visitsShouldBeCounted = true
    end
    if compat.band(value, CountFlags.Turns) > 0 then
        self.turnIndexShouldBeCounted = true
    end
    if compat.band(value, CountFlags.CountStartOnly) > 0 then
        self.countingAtStartOnly = true
    end
end


function Container:__tostring()
    return "Container"
end

return Container
