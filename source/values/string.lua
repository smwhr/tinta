local StringValue = BaseValue:extend()

function StringValue:new(val)

    StringValue.super.new(self, val)

    self.isNewline = false
    self.isInlineWhiteSpace = false

    if string.len(self.value) == 1 and string.sub(self.value, 1, 1) == "\n" then
        self.isNewline = true
    end

    self.isInlineWhiteSpace = true
    for i = 1, string.len(self.value) do
        local c = self.value:sub(i,i)
        if c ~= " " and c ~= "\t" then
            self.isInlineWhiteSpace = false
            break
        end
    end

    self.valueType = "String"

end

function StringValue:isNonWhitespace()
    return not self.isNewline and not self.isInlineWhiteSpace
end

function StringValue:isTruthy()
    return #self.value > 0
end

function StringValue:Cast(newType)

    if newType == self.valueType then
        return self
    end

    if newType == "Int" then
        local try = tonumber(self.value)
        if try then
            return IntValue(self.value)
        else
            self:BadCast(newType)
        end
    end

    if newType == "Float" then
        local try = tonumber(self.value)
        if try then
            return FloatValue(self.value)
        else
            self:BadCast(newType)
        end
    end

    self:BadCast(newType)
end

return StringValue