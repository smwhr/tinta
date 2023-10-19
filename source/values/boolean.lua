local BooleanValue = BaseValue:extend()

function BooleanValue:new(val)

    BooleanValue.super.new(self, val)

    self.valueType = "Bool"

end

function BooleanValue:isTruthy()
    return self.value
end

function BooleanValue:Cast(newType)

    if newType == self.valueType then
        return self
    end

    if newType == "Int" then
        return IntValue(self.value and 1 or 0)
    end

    if newType == "Float" then
        return FloatValue(self.value and 1 or 0)
    end

    if newType == "String" then
        return StringValue(self.value and "true" or "false")
    end

    self:BadCast(newType)
end

return BooleanValue