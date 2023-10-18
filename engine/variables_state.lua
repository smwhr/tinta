local classic = import('libs.classic')
local lume = import('libs.lume')
local inkutils = import('libs.inkutils')

local VariablePointerValue = import('values.variable_pointer')
local ListValue = import('values.list.list_value')

---@class VariablesState
local VariablesState = classic:extend()

function VariablesState:new(callStack, listDefsOrigin)
    self.globalVariables = {}
    self.callStack = callStack
    self.listDefsOrigin = listDefsOrigin or {}

    self.dontSaveDefaultValues = true

    self.defaultGlobalVariables = nil
    self.patch = nil
    
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
end

function VariablesState:GetVariableWithName(name, contextIndex)
    contextIndex = contextIndex or 0
    local varValue = self:GetRawVariableWithName(name, contextIndex)

    if varValue:is(VariablePointerValue) then
        local varPointer = varValue
        varValue = self:ValueAtVariablePointer(varPointer)
    end
    return varValue
end

function VariablesState:GlobalVariableExistsWithName(name)
    return ( self.globalVariables[name] ~= nil
       or ( self.defaultGlobalVariables ~= nil
            and self.defaultGlobalVariables ~= nil )
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
        setGlobal = self:GlobalVariableExistsWithName(name, contextIndex)
    end

    if varAss.isNewDeclaration then
        if value:is(VariablePointerValue) then
            local varPointer = value
            local fullyResolvedVariablePointer = self:ResolvedVariablePointer(varPointer)
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
        self.callStack:SetTemporaryVariable(name, value, contextIndex)
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
    --@TODO
    error("Not implemented yet")
end

function VariablesState:__tostring()
    return "VariablesState"
end

return VariablesState
