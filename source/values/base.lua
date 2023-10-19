local BaseValue = classic:extend()

function BaseValue:new(val)

    self.value = val
    self.valueType = "UNKNOWN"

end

function BaseValue:isTruthy()
    return not not self.value
end

function BaseValue:BadCast(targetType)
    error("Can't cast ".. self.value .. " from " .. self.valueType .. " to " .. targetType)
end

function BaseValue:__tostring()
    return tostring(self.value)
end

return BaseValue