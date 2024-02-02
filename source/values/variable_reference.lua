local VariableReference = classic:extend()

function VariableReference:new(name)
    self.name = name
    self.pathForCount = nil -- Path
end

function VariableReference:pathStringForCount()
    return Path:of(self):CompactPathString(self.pathForCount)
end


function VariableReference:setPathStringForCount(value)
    if value == nil then self.pathForCount = nil end
    self.pathForCount = Path:FromString(value);
end

function VariableReference:containerForCount()
    if self.pathForCount == nil then return nil end
    return Path:Resolve(self, self.pathForCount):container()
end

function VariableReference:__tostring()
    if self.name ~= nil then
        return "var(".. self.name .. ")"
    else
        local pathStr = "null"
        if self.pathForCount then
            pathStr = self.pathForCount:componentsString()
        else
            error("")
        end
        return "read_count(" .. pathStr .. ")"
    end
end

return VariableReference