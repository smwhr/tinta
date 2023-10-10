local classic = require('libs.classic')
local BaseValue = require('values.base')

---@class VariablePointer
local VariablePointer = BaseValue:extend()

function VariablePointer:new(varName, contextIndex)

    VariablePointer.super.new(self, varName)

    self.contextIndex = contextIndex or -1
    self.valueType = "VariablePointer"
end

function VariablePointer:__tostring()
    return "VariablePointer"
end

return VariablePointer