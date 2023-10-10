local classic = require('libs.classic')
local BaseValue = require('values.base')


---@class BooleanValue
local BooleanValue = BaseValue:extend()

function BooleanValue:new(val)

    BooleanValue.super.new(self, val)

    self.valueType = "Bool"

end

function BooleanValue:isTruthy()
    return self.value
end

function BooleanValue:__tostring()
    return "BooleanValue"
end

return BooleanValue