local classic = require('libs.classic')
local lume = require('libs.lume')


---@class VariableReference
local VariableReference = classic:extend()

function VariableReference:new(name)
    self.name = name
    self.pathForCount = nil
end

function VariableReference:containerForCount()
    if self.pathForCount == nil then return nil end
    return Path:Resolve(self, self.pathForCount).container
end

return VariableReference