local classic = require('libs.classic')
local BaseValue = require('values.base')


---@class IntValue
local IntValue = BaseValue:extend()

function IntValue:new(val)

    IntValue.super.new(self, val)

    self.valueType = "Int"

end

function IntValue:isTruthy()
    return self.value ~= 0
end

function IntValue:__tostring()
    return "IntValue"
end

return IntValue