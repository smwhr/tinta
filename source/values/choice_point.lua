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

function ChoicePoint:flags(value)
    local flags = 0

    if self.hasCondition then
        flags = (flags | 1);
    end 
    if self.hasStartContent then
        flags = (flags | 2);
    end 
    if self.hasChoiceOnlyContent then
        flags = (flags | 4);
    end 
    if self.isInvisibleDefault then
        flags = (flags | 8);
    end 
    if self.onceOnly then
        flags = (flags | 16);
    end 
    return flags
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

function ChoicePoint:pathStringOnChoice()
    return Path:of(self):CompactPathString(self:pathOnChoice())
end

function ChoicePoint:__tostring()
    return "Choice: -> " .. self:pathOnChoice():componentsString()
end

return ChoicePoint