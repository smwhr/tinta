local classic = require('libs.classic')
local BaseValue = require('values.base')

---@class NativeFunctionCall
local NativeFunctionCall = BaseValue:extend()

function NativeFunctionCall:__tostring()
    return "NativeFunctionCall"
end

return NativeFunctionCall