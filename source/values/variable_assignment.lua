local VariableAssignment = classic:extend()

function VariableAssignment:new(variableName, isNewDeclaration, isGlobal)
    self.variableName = variableName or nil
    self.isNewDeclaration = isNewDeclaration or false
    self.isGlobal = isGlobal or false
end

function VariableAssignment:__tostring()
    return "VarAssign to " .. self.variableName
end

return VariableAssignment