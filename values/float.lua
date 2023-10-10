local classic = require('libs.classic')
local BaseValue = require('values.base')


---@class FloatValue
local FloatValue = BaseValue:extend()

function FloatValue:new(val)

    FloatValue.super.new(self, val)

    self.valueType = "Float"

end

function FloatValue:isTruthy()
    return self.value ~= 0
end

function FloatValue:__tostring()
    return "FloatValue"
end

return FloatValue