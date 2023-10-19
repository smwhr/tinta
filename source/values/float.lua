local FloatValue = BaseValue:extend()

function FloatValue:new(val)

    FloatValue.super.new(self, val)

    self.valueType = "Float"

end

function FloatValue:isTruthy()
    return self.value ~= 0
end

function FloatValue:Cast(newType)

    if newType == self.valueType then
        return self
    end

    if newType == "Boolean" then
        return BooleanValue(self.value ~= 0)
    end

    if newType == "Int" then
        return IntValue(self.value)
    end

    if newType == "String" then
        return StringValue(tostring(self.value))
    end

    self:BadCast(newType)
end

return FloatValue