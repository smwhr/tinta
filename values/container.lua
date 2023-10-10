local lume = require('libs.lume')
local classic = require('libs.classic')

local SearchResult = require('values.search_result')

local CountFlags = {
    Visits = 1,
    Turns = 2,
    CountStartOnly = 4,
}

---@class Container
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
        table.insert(self.content, contentOrList)
        if contentOrList.name then
            self.namedContent[contentOrList.name] = contentOrList
        end
        contentOrList.parent = self
    end
end

function Container:ContentAtPath(path, partialStart, partialEnd)
    partialStart = partialStart or 1
    partialEnd = partialEnd or path:length()
    local result = SearchResult()
    result.approximate = false
    local currentContainer = self
    local currentObj = self

    for i = partialStart + 1, partialEnd do
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
        if currentObj:is(Container) then
            currentContainer = currentObj
        else
            currentContainer = nil
        end
    end
    result.obj = currentObj
    return result
end

function Container:ContentWithPathComponent(component)
    if component:isIndex() then
        if component.index >= 1 or component.index <= #self.content then
            return self.content[component.index]
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

function Container:setCountFlags(flag)
    if flag & CountFlags.Visits > 0 then
        self.visitsShouldBeCounted = true
    end
    if flag & CountFlags.Turns > 0 then
        self.turnIndexShouldBeCounted = true
    end
    if flag & CountFlags.CountStartOnly > 0 then
        self.countingAtStartOnly = true
    end
end


function Container:__tostring()
    return "Container"
end

return Container
