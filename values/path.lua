local classic = require('libs.classic')
local lume = require('libs.lume')
local BaseValue = require('values.base')
local Container = require('values.container')

---@class PathComponent
local PathComponent = classic:extend()

function PathComponent:new(indexOrName)
    self.index = 0
    self.name = nil

    if type(indexOrName) == "string" then
        self.name = indexOrName
    else
        self.index = indexOrName
    end
end

function PathComponent:isIndex()
    return self.index >= 1
end

function PathComponent:isParent()
    return self.name == Path.parentId
end

function PathComponent:ToParent()
    return PathComponent(Path.parentId)
end

function PathComponent:__tostring()
    return "PathComponent"
end


---@class Path
local Path = classic:extend()


function Path:new()
    self.parentId = "^"
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
        error("Can't get tail of an empty path")
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
        self.isRelative = true
        strComponents = string.sub(strComponents, 2)
    end 

    local comps = lume.split(strComponents, ".")
    for _, comp in ipairs(comps) do
        if tonumber(comp) then
            table.insert(newPath.components, tonumber(comp))
        else
            table.insert(newPath.components, comp)
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

function Path:of(element)
    if element.path == nil then
        if element.parent == nil then
            element.path = Path()
        else
            local comps = {}
            local child = element
            local container = child.parent
            while container:is(Container) do
                if container.name then
                    table.insert(comps, 1, PathComponent(container.name))
                else
                    local childIndex = lume.find(container.content, child)
                    table.insert(comps, 1, PathComponent(childIndex))
                end
                child = container
                container = container.parent
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
    if ancestor:is(Container) then
        return ancestor
    else
        return nil
    end
end

function Path:Resolve(obj, path)
    if path == nil then
        error("Can't resolve a nil path")
    end
    if path.isRelative then
        local nearestContainer = obj
        if not nearestContainer:is(Container) then
            if obj.parent == nil then
                error("Can't resolve relative path because we don't have a parent")
            end
            nearestContainer = obj.parent
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

function Path:componentString()
    local componentString = ""
    componentString = lume.reduce(self.components, function(acc, comp)
        if type(comp) == "string" then
            return acc .. "." .. comp
        else
            return acc .. "." .. tostring(comp)
        end
    end)
    if self.isRelative then
        return "." .. componentString
    else
        return componentString
    end
end

function Path:__tostring()
    return "Path"
end

return Path