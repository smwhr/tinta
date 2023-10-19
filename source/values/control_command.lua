local ControlCommand = BaseValue:extend()

function ControlCommand:__tostring()
    return "ControlCommand ".. self.value
end

return ControlCommand