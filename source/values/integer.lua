local IntValue = BaseValue:extend()

function IntValue:new(val)

    IntValue.super.new(self, val)

    self.valueType = "Int"

end

function IntValue:isTruthy()
    return self.value ~= 0
end

function IntValue:Cast(newType)

    if newType == self.valueType then
        return self
    end

    if newType == "Boolean" then
        return BooleanValue(self.value ~= 0)
    end

    if newType == "Float" then
        return FloatValue(self.value)
    end

    if newType == "String" then
        return StringValue(tostring(self.value))
    end

    self:BadCast(newType)
end

return IntValue