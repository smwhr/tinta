local classic = require('libs.classic')

---@class Glue
local Glue = classic:extend()

function Glue:__tostring()
    return "Glue"
end

return Glue