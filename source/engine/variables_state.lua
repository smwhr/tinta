---@class VariableState
---@field patch StatePatch
---@field callStack CallStack
local VariablesState = classic:extend()

function VariablesState:new(callStack, listDefsOrigin)
    self.globalVariables = {}
    self.variableChangedEvent = DelegateUtils.createDelegate()
    self.callStack = callStack
    self.listDefsOrigin = listDefsOrigin or {}
    self._batchObservingVariableChanges = false
    self._changedVariablesForBatchObs = {}

    self.dontSaveDefaultValues = true

    self.defaultGlobalVariables = nil
    self.patch = nil
end

function VariablesState:batchObservingVariableChanges(setValue)
    if setValue == nil then
        return self._batchObservingVariableChanges
    end

    self._batchObservingVariableChanges = setValue
    if setValue then
        self._changedVariablesForBatchObs = {}
    else
        if (self._changedVariablesForBatchObs ~= nil) then
            for _, variableName in ipairs(self._changedVariablesForBatchObs) do
                local currentValue = self.globalVariables[variableName]
                self.variableChangedEvent(variableName, currentValue)
            end
        end
    end
end

function VariablesState:SnapshotDefaultGlobals()
    self.defaultGlobalVariables = lume.clone(self.globalVariables)
end

function VariablesState:SetGlobal(variableName, value)
    local oldValue = nil
    if self.patch == nil then
        oldValue = self.globalVariables[variableName]
    end

    if self.patch ~= nil then
        oldValue = self.patch:TryGetGlobal(variableName, nil)
        if not oldValue.exists then
            oldValue = self.globalVariables[variableName]
        else
            oldValue = oldValue.result
        end
    end

    ListValue:RetainListOriginsForAssignment(oldValue, value)

    if self.patch ~= nil then
        self.patch:SetGlobal(variableName, value)
    else
        self.globalVariables[variableName] = value
    end

    if self.variableChangedEvent:hasAnySubscriber() and oldValue and value.value ~= oldValue.value then
        if self:batchObservingVariableChanges() then
            if self.patch ~= nil then
                self.patch:AddChangedVariable(variableName)
            elseif self._changedVariablesForBatchObs ~= nil then
                table.insert(self._changedVariablesForBatchObs, variableName)
            end
        else
            self.variableChangedEvent(variableName, currentValue)
        end
    end
end

function VariablesState:GetVariableWithName(name, contextIndex)
    contextIndex = contextIndex or 0
    local varValue = self:GetRawVariableWithName(name, contextIndex)
    local varPointer = inkutils.asOrNil(varValue, VariablePointerValue)
    if varPointer then
        varValue = self:ValueAtVariablePointer(varPointer)
    end
    return varValue
end

function VariablesState:GlobalVariableExistsWithName(name)
    return (self.globalVariables[name] ~= nil
        or (self.defaultGlobalVariables ~= nil
            and self.defaultGlobalVariables[name] ~= nil)
    )
end

function VariablesState:GetRawVariableWithName(name, contextIndex)
    if contextIndex == 1 or contextIndex == 0 then
        local variableValue = nil

        if self.patch ~= nil then
            variableValue = self.patch:TryGetGlobal(name, nil)
            if variableValue.exists then return variableValue.result end
        end

        variableValue = self.globalVariables[name]
        if variableValue ~= nil then return variableValue end
        if self.defaultGlobalVariables ~= nil then
            variableValue = self.defaultGlobalVariables[name]
            if variableValue ~= nil then return variableValue end
        end
        local listItemValue = self.listDefsOrigin:FindSingleItemListWithName(name)
        if listItemValue then return listItemValue end
    end

    return self.callStack:GetTemporaryVariableWithName(name, contextIndex)
end

function VariablesState:ValueAtVariablePointer(pointer)
    return self:GetVariableWithName(pointer.variableName, pointer.contextIndex)
end

function VariablesState:Assign(varAss, value)
    local name = varAss.variableName
    local contextIndex = 0

    local setGlobal = false

    if varAss.isNewDeclaration then
        setGlobal = varAss.isGlobal
    else
        setGlobal = self:GlobalVariableExistsWithName(name)
    end

    if varAss.isNewDeclaration then
        local varPointer = inkutils.asOrNil(value, VariablePointerValue)
        if varPointer ~= nil then
            local fullyResolvedVariablePointer = self:ResolveVariablePointer(varPointer)
            value = fullyResolvedVariablePointer
        end
    else
        local existingPointer = nil
        repeat
            existingPointer = inkutils.asOrNil(
                self:GetRawVariableWithName(name, contextIndex),
                VariablePointerValue
            )

            if existingPointer ~= nil then
                name = existingPointer.variableName
                contextIndex = existingPointer.contextIndex
                setGlobal = contextIndex == 1
            end
        until existingPointer == nil
    end

    if setGlobal then
        self:SetGlobal(name, value)
    else
        self.callStack:SetTemporaryVariable(
            name,
            value,
            varAss.isNewDeclaration,
            contextIndex
        )
    end
end

function VariablesState:ResolveVariablePointer(varPointer)
    local contextIndex = varPointer.contextIndex

    if contextIndex == 0 then
        contextIndex = self:GetContextIndexOfVariableNamed(varPointer.variableName)
    end

    local valueOfVariablePointedTo = self:GetRawVariableWithName(varPointer.variableName, contextIndex)

    if valueOfVariablePointedTo:is(VariablePointerValue) then
        local doubleRedirectionPointer = valueOfVariablePointedTo
        return doubleRedirectionPointer
    else
        return VariablePointerValue(varPointer.variableName, contextIndex)
    end
end

function VariablesState:GetContextIndexOfVariableNamed(varName)
    if self:GlobalVariableExistsWithName(varName) then
        return 1
    end

    return self.callStack:currentElementIndex()
end

function VariablesState:ApplyPatch()
    for namedVarKey, namedVarValue in pairs(self.patch._globals) do
        self.globalVariables[namedVarKey] = namedVarValue
    end
    self.patch = nil
end

-- Can't declare a
function VariablesState:_(variableName, value)
    if value == nil then
        local varContents = nil
        if self.patch ~= nil then
            varContents = self.patch:TryGetGlobal(variableName, nil)
            if varContents.exists then
                return varContents.result.value
            end
        end
        varContents = self.globalVariables[variableName]
        if varContents == nil then
            varContents = self.defaultGlobalVariables[variableName]
        end

        if varContents ~= nil then
            return varContents.value
        else
            return nil
        end
    else
        if self.defaultGlobalVariables[variableName] == nil then
            error("Cannot assign to a variable (" .. variableName .. ") that hasn't been declared in the story")
        end

        local val = CreateValue(value)
        if val == nil then
            error("Invalid value passed to VariableState: " .. dump(value))
        end

        self:SetGlobal(variableName, val)
    end
end

function VariablesState:save()
    local returnObject = {}
    for keyValKey, keyValValue in pairs(self.globalVariables) do
        local name = keyValKey
        local val = keyValValue

        local shouldSave = true

        if self.dontSaveDefaultValues then
            if self.defaultGlobalVariables[name] ~= nil then
                local defaultVal = self.defaultGlobalVariables[name]
                if self:RuntimeObjectsEqual(val, defaultVal) then
                    shouldSave = false
                end
            end
        end

        if shouldSave then
            returnObject[name] = serialization.WriteRuntimeObject(val)
        end
    end

    return returnObject
end

-- SetJsonToken
function VariablesState:load(jToken)
    self.globalVariables = {}
    for varValKey, varValValue in pairs(self.defaultGlobalVariables) do
        local loadedToken = jToken[varValKey]
        if loadedToken ~= nil then
            local tokenInkObject = serialization.JTokenToRuntimeObject(loadedToken)
            self.globalVariables[varValKey] = tokenInkObject
        else
            self.globalVariables[varValKey] = varValValue
        end
    end
end

function VariablesState:RuntimeObjectsEqual(obj1, obj2)
    if obj1["valueType"] ~= obj2["valueType"] then
        return false
    end

    if obj1:is(BaseValue) and obj2:is(BaseValue) then
        if obj1["Equals"] ~= nil and obj2["Equals"] ~= nil then
            return obj1:Equals(obj2)
        else
            return obj1.value == obj2.value
        end
    end
end

function VariablesState:__tostring()
    return "VariablesState"
end

return VariablesState
