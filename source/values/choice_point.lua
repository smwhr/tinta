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
    self.hasCondition = compat.band(value, 1) > 0;
    self.hasStartContent = compat.band(value, 2) > 0;
    self.hasChoiceOnlyContent = compat.band(value, 4) > 0;
    self.isInvisibleDefault = compat.band(value, 8) > 0;
    self.onceOnly = compat.band(value, 16) > 0;
end

function ChoicePoint:flags(value)
    local flags = 0

    if self.hasCondition then
        flags = compat.bor(flags, 1);
    end 
    if self.hasStartContent then
        flags = compat.bor(flags, 2);
    end 
    if self.hasChoiceOnlyContent then
        flags = compat.bor(flags, 4);
    end 
    if self.isInvisibleDefault then
        flags = compat.bor(flags, 8);
    end 
    if self.onceOnly then
        flags = compat.bor(flags, 16);
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