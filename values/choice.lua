local classic = import('libs.classic')
local BaseValue = import('values.base')

local Path = import('values.path')

---@class Choice
local Choice = classic:extend()

function Choice:new()
    self.text = ""
    self.index = 1
    self.threadAtGeneration = nil
    self.sourcePath = ""
    self.targetPath = nil
    self.isInvisibleDefault = false
    self.tags = {}
    self.originalThreadIndex = 1
end

return Choice