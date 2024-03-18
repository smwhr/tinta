local ParentID = "^"

local PathComponent = classic:extend()

function PathComponent:new(indexOrName)
    self.index = -1
    self.name = nil

    if type(indexOrName) == "string" then
        self.name = indexOrName
    else
        self.index = indexOrName
    end
end

function PathComponent:isIndex()
    return self.index >= 0
end

function PathComponent:isParent()
    return self.name == ParentID
end

function PathComponent:ToParent()
    return PathComponent(ParentID)
end

function PathComponent:asString()
    if self:isIndex() then
        return tostring(self.index)
    else
        return self.name;
    end
end

function PathComponent:Equals(otherComp)
    if otherComp ~= nil and otherComp:isIndex() == self:isIndex() then
        if self:isIndex() then
            return self.index == otherComp.index
        else
            return self.name == otherComp.name
        end
    end
end

function PathComponent:__tostring()
    return "PathComponent"
end




---@class Path
local Path = classic:extend()


function Path:new()
    self.components = {}
    self.isRelative = false
end

function Path:length()
    return #self.components
end

function Path:lastComponent()
    return self.components[#self.components]
end

function Path:tail()
    if self:length() >= 2 then
        local comps = lume.slice(self.components, 2)
        return Path:fromPathComponents(comps)
    else
        local p = Path()
        p.isRelative = true
        return p
    end
end

function Path:FromString(strComponents)
    local newPath = Path()

    if string.sub(strComponents, 1, 1) == "." then
        newPath.isRelative = true
        strComponents = string.sub(strComponents, 2)
    end 

    local comps = lume.split(strComponents, ".")
    for _, comp in ipairs(comps) do
        if tonumber(comp) then
            table.insert(newPath.components, PathComponent(tonumber(comp)))
        else
            table.insert(newPath.components, PathComponent(comp))
        end
    end

    return newPath
end

function Path:fromPathComponents(components, relative)
    local path = Path()
    path.components = components
    path.isRelative = relative or false
    return path
end

function Path:ByAppendingPath(pathToAppend)
    local newPathComps = {}
    local upwardMoves = 0
    for _,comp in pairs(self.components) do
        if comp:isParent() then
            upwardMoves = upwardMoves + 1
        else
            break
        end
    end

    for i = 1, self:length() - upwardMoves do
        table.insert(newPathComps, self.components[i])
    end

    for i = upwardMoves, pathToAppend:length() do
        table.insert(newPathComps, pathToAppend.components[i])
    end

    return Path:fromPathComponents(newPathComps)
end

function Path:of(element)
    if element.path == nil then
        if element.parent == nil then
            element.path = Path()
        else
            local comps = {}
            local child = element
            local container = inkutils.asOrNil(child.parent, Container)
            while container ~= nil do
                if child.name and child:is(Container) then
                    table.insert(comps, 1, PathComponent(child.name))
                else
                    local childIndex = lume.find(container.content, child) -1 
                    table.insert(comps, 1, PathComponent(childIndex))
                end
                child = container
                container = inkutils.asOrNil(container.parent, Container)
            end

            element.path = Path:fromPathComponents(comps)
        end
    end
    return element.path
end

function Path:rootAncestorOf(obj)
    local ancestor = obj
    while ancestor.parent ~= nil do
        ancestor = ancestor.parent
    end
    return inkutils.asOrNil(ancestor, Container)
end

function Path:Resolve(obj, path)
    if path == nil then
        error("Can't resolve a nil path")
    end
    if path.isRelative then
        local nearestContainer = inkutils.asOrNil(obj, Container)
        
        if nearestContainer == nil then
            
            if obj.parent == nil then
                error("Can't resolve relative path because we don't have a parent")
            end
            nearestContainer = inkutils.asOrNil(obj.parent, Container)
            if not nearestContainer:is(Container) then
                error("Expected parent to be a container")
            end
            path = path:tail()
        end
        if nearestContainer == nil then
            error("Expected to find a nearestContainer")
        end
        return nearestContainer:ContentAtPath(path)
    else
        local contentContainer = Path:rootAncestorOf(obj)

        if contentContainer == nil then
            error("Can't resolve path of object that doesn't belong to a container")
        end
        return contentContainer:ContentAtPath(path)
    end
end

function Path:componentsString()
    local sb = {}

    for _,comp in pairs(self.components) do
        table.insert(sb, comp:asString())
    end

    local componentString = table.concat(sb, ".")
    if self.isRelative then
        return "." .. componentString
    else
        return componentString
    end
end

function Path:ConvertPathToRelative(globalPath)
    local ownPath = self
    local minPathLength = math.min(globalPath:length(), ownPath:length())

    local lastSharedPathCompIndex = 0
    for i = 1, minPathLength do
        local ownComp = ownPath.components[i]
        local otherComp = globalPath.components[i]
        
        if ownComp:Equals(otherComp) then
            lastSharedPathCompIndex = i
        else
            break
        end
    end

    if lastSharedPathCompIndex == 0 then
        return globalPath
    end

    local numUpwardMoves = ownPath:length() - 1 - lastSharedPathCompIndex
    local newPathComps = {}
    for up = 1, numUpwardMoves do
        table.insert(newPathComps, PathComponent:ToParent())
    end

    for down = lastSharedPathCompIndex + 1, globalPath:length(), -1 do
        table.insert(newPathComps,globalPath[down])
    end

    return Path:fromPathComponents(newPathComps)
end

function Path:CompactPathString(otherPath)
    local globalPathStr = nil
    local relativePathStr = nil

    if otherPath.isRelative then
        relativePathStr = otherPath:componentsString()
        globalPathStr = self:ByAppendingPath(otherPath):componentsString()
    else
        local relativePath = self:ConvertPathToRelative(otherPath)
        relativePathStr = relativePath:componentsString()
        globalPathStr = otherPath:componentsString()
    end

    if #relativePathStr < #globalPathStr then
        return relativePathStr
    else
        return globalPathStr
    end

end

function Path:__tostring()
    return "Path"
end

return Path