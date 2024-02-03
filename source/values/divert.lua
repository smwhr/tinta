local Divert = classic:extend()

function Divert:new(pushesToStack, stackPushType, isExternal)
    self.pushesToStack = pushesToStack or false
    self.stackPushType = stackPushType or PushPopType.Function
    self.isExternal = isExternal or false

    self.isConditional = false
    self.externalArgs = 0
    
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

function Divert:targetPathString()
    if self:targetPath() == nil then
        return nil
    end
    return Path:of(self):CompactPathString(self:targetPath())
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

function Divert:Equals(obj)
    local otherDivert = obj
    if otherDivert:is(Divert) then
        if self:hasVariableTarget() == otherDivert:hasVariableTarget() then
            if self:hasVariableTarget() then
                return self.variableDivertName == otherDivert.variableDivertName
            else
                return self:targetPath():Equals(otherDivert:targetPath())
            end
        end
    end
    return fals
end

function Divert:__tostring()
    if self:hasVariableTarget() then
        return "Divert(variable: " .. self.variableDivertName .. ")"
    elseif self:targetPath() == nil then
        return "Divert(null)"
    else
        local sb = {}
        table.insert( sb,  "Divert" )

        if self.isConditional then table.insert(sb, "?") end

        if self.pushesToStack then
            if self.stackPushType == PushPopType.Function then
                table.insert(sb, " function")
            else
                table.insert(sb, " tunnel")    
            end
        end

        table.insert( sb, " -> " )
        table.insert( sb, self:targetPath():componentsString())
        return table.concat(sb)

    end
end

return Divert