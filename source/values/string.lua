local StringValue = BaseValue:extend()

function StringValue:new(val)

    StringValue.super.new(self, val)

    self.isNewLine = false
    self.isInlineWhiteSpace = false

    if string.len(self.value) == 1 and string.sub(self.value, 1, 1) == "\n" then
        self.isNewLine = true
    end

    if self.value:gsub('^%s*(.-)%s*$', '%1') == "" then
        self.isInlineWhiteSpace = true
    end

end

function StringValue:isNonWhitespace()
    return not self.isNewLine and not self.isInlineWhiteSpace
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