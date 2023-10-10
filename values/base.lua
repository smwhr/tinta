local classic = require('libs.classic')


---@class BaseValue
local BaseValue = classic:extend()

function BaseValue:new(val)

    self.value = val

end

function BaseValue:isTruthy()
    return not not self.value
end

function BaseValue:__tostring()
    return "BaseValue"
end

return BaseValue