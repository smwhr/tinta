local classic = require('libs.classic')
local BaseValue = require('values.base')

local Path = require('values.path')

---@class ChoicePoint
local ChoicePoint = classic:extend()

function ChoicePoint:new(onceOnly)
    self.onceOnly = onceOnly or true
    self._pathOnChoice = nil;
    self.hasCondition = false;
    self.hasStartContent = false;
    self.hasChoiceOnlyContent = false;
    self.isInvisibleDefault = false;
    self.onceOnly = true;
end

function ChoicePoint:choiceTarget()
    return Path:Resolve(self, self._pathOnChoice).container
end

function ChoicePoint:__tostring()
    return "ChoicePoint"
end

return ChoicePoint