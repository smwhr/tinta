local Divert = classic:extend()

function Divert:new(pushesToStack, stackPushType, isExternal)
    self.pushesToStack = pushesToStack or false
    self.stackPushType = stackPushType or PushPopType.Function
    self.isExternal = isExternal or false

    self.isConditional = false
    self.externalArgs = {}
    
    self.variableDivertName = nil

    self._targetPath = nil
    self._targetPointer = Pointer:Null()

end

function Divert:hasVariableTarget()
    return self.variableDivertName ~= nil
end

function Divert:targetPath()
    if self._targetPath ~= nil and self._targetPath.isRelative then
        local targetObj = self:targetPointer():Resolve()
        if targetObj then
            self._targetPath = Path:of(targetObj)
        end
    end
    return self._targetPath
end

function Divert:setTargetPath(value)
    self._targetPath = value
    self._targetPointer = Pointer:Null()
end

function Divert:setTargetPathString(value)
    if value == nil then
        self:setTargetPath(nil)
    else
        self:setTargetPath(Path:FromString(value))
    end
end

function Divert:targetPointer()
    if self._targetPointer:isNull() then
        local targetObj = Path:Resolve(self, self._targetPath).obj

        if self._targetPath:lastComponent():isIndex() then
            self._targetPointer.container = inkutils.asOrNil(targetObj.parent, Container)
            self._targetPointer.index = self._targetPath:lastComponent().index + 1;
        else
            self._targetPointer = Pointer:StartOf(inkutils.asOrNil(targetObj,Container))
        end
    end

    return self._targetPointer:Copy()
end

function Divert:__tostring()
    return "Divert"
end

return Divert