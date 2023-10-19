---@class Pointer
local Pointer = classic:extend()

function Pointer:new(container, index)
    self.container = container or nil
    self.index = index or 0
end

function Pointer:Copy()
    return Pointer(self.container, self.index)
end

function Pointer:StartOf(container)
    return Pointer(container, 1)
end

function Pointer:isNull()
    return self.container == nil
end

function Pointer:Resolve()
    if self.index < 1 then return self.container end
    if self.container == nil then return nil end
    if #(self.container.content) == 0 then return self.container end
    if self.index > #self.container.content then return nil end
    
    return self.container.content[self.index]
end

function Pointer:Null()
    return Pointer(nil, 0)
end

function Pointer:__tostring()
    return "Pointer"
end

return Pointer
