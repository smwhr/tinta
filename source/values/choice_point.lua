local classic = import('libs.classic')
local BaseValue = import('values.base')

local Path = import('values.path')

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

function ChoicePoint:setFlags(value)
    self.hasCondition = (value & 1) > 0;
    self.hasStartContent = (value & 2) > 0;
    self.hasChoiceOnlyContent = (value & 4) > 0;
    self.isInvisibleDefault = (value & 8) > 0;
    self.onceOnly = (value & 16) > 0;
end

function ChoicePoint:choiceTarget()
    return Path:Resolve(self, self._pathOnChoice):container()
end

function ChoicePoint:pathOnChoice()
      if self._pathOnChoice ~= nil and self._pathOnChoice.isRelative then
        local choiceTargetObj = self:choiceTarget()
        if choiceTargetObj then
            self._pathOnChoice = Path:of(choiceTargetObj)
        end
      end
      return self._pathOnChoice
end

function ChoicePoint:__tostring()
    return "ChoicePoint"
end

return ChoicePoint