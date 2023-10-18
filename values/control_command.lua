local classic = import('libs.classic')
local BaseValue = import('values.base')

---@class ControlCommand
local ControlCommand = BaseValue:extend()

function ControlCommand:__tostring()
    return "ControlCommand ".. self.value
end

return ControlCommand