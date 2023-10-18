local classic = require('libs.classic')
local BaseValue = require('values.base')

---@class ControlCommand
local ControlCommand = BaseValue:extend()

function ControlCommand:__tostring()
    return "ControlCommand ".. self.value
end

return ControlCommand