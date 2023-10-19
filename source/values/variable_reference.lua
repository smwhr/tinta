local VariableReference = classic:extend()

function VariableReference:new(name)
    self.name = name
    self.pathForCount = nil
end


function VariableReference:setPathStringForCount(value)
    if value == nil then self.pathForCount = nil end
    self.pathForCount = Path(value);
end

function VariableReference:containerForCount()
    if self.pathForCount == nil then return nil end
    return Path:Resolve(self, self.pathForCount):container()
end

function VariableReference:__tostring()
    return "VariableReference"
end

return VariableReference