local ControlCommand = classic:extend()

function ControlCommand:new(val)
    self.value = val
end

function ControlCommand:__tostring()
    return "ControlCommand ".. self.value
end

return ControlCommand