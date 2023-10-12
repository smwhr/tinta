local classic = require('libs.classic')


---@class InkList
local InkList = classic:extend()

function InkList:__tostring()
    return "InkList"
end

return InkList