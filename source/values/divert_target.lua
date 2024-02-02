local DivertTarget = BaseValue:extend()

function DivertTarget:new(targetPath)
    
    DivertTarget.super.new(self, targetPath)

    self.valueType = "DivertTarget"
end

function DivertTarget:targetPath()
    return self.value
end

function DivertTarget:Cast(newType)

    if newType == self.valueType then
        return self
    end

    self:BadCast(newType)
end

function DivertTarget:__tostring()
    return  "DivertTargetValue(" .. self:targetPath():componentsString() .. ")";
end

return DivertTarget