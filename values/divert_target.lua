local classic = require('libs.classic')
local BaseValue = require('values.base')

---@class DivertTarget
local DivertTarget = BaseValue:extend()

function DivertTarget:new(targetPath)
    
    DivertTarget.super.new(self, targetPath)

    self.valueType = "DivertTarget"
end

function DivertTarget:targetPath()
    return self.value
end

function DivertTarget:__tostring()
    return "DivertTarget"
end

return DivertTarget