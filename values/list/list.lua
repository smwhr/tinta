local classic = require('libs.classic')


---@class ListValue
local ListValue = classic:extend()

function ListValue:__tostring()
    return "ListValue"
end

return ListValue