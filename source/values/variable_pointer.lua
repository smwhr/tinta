local VariablePointer = BaseValue:extend()

function VariablePointer:new(varName, contextIndex)

    VariablePointer.super.new(self, varName)

    self.variableName = varName
    self.contextIndex = contextIndex or 0
    self.valueType = "VariablePointer"
end

function VariablePointer:Cast(newType)

    if newType == self.valueType then
        return self
    end

    self:BadCast(newType)
end

function VariablePointer:__tostring()
    return "VariablePointer"
end

return VariablePointer