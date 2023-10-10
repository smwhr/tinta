local classic = require('libs.classic')
local lume = require('libs.lume')

local VariablePointerValue = require('values.variable_pointer')

---@class VariableState
local VariableState = classic:extend()

function VariableState:new(callStack, listDefsOrigin)
    self.globalVariables = {}
    self.callStack = callStack
    self.listDefsOrigin = listDefsOrigin or {}

    self.dontSaveDefaultValues = true

    self.defaultGlobalVariables = nil
    
end

function VariableState.SnapshotDefaultGlobals()
    self.defaultGlobalVariables = lume.clone(self.globalVariables)
end

function VariableState:GetVariableWithName(name, contextIndex)
    contextIndex = contextIndex or 0
    local varValue = self:GetRawVariableWithName(name, contextIndex)

    if varValue:is(VariablePointerValue) then
        local varPointer = varValue
        varValue = self:ValueAtVariablePointer(varPointer)
    end
    return varValue
end

function VariableState:GlobalVariableExistsWithName(name)
    return ( self.globalVariables[name] ~= nil
       or ( self.defaultGlobalVariables ~= nil
            and self.defaultGlobalVariables ~= nil )
    )
end

function VariableState:GetRawVariableWithName(name, contextIndex)
    local varValue = nil
    if contextIndex == 0 or contextIndex == 1 then
        varValue = self.globalVariables[name]
        if varValue ~= nil then return varValue end

        if self.defaultGlobalVariables ~= nil then
            varValue = self.defaultGlobalVariables[name]
            if varValue ~= nil then return varValue end
        end
    end

    return self.callStack:GetTemporaryVariableWithName(name, contextIndex)
end

function VariableState:ValueAtVariablePointer(pointer)
    return self:GetVariableWithName(pointer.variableName, pointer.contextIndex)
end

function VariableState:Assign(varAss, value)
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
    end

    if contextIndex == 0 or contextIndex == 1 then
        self.globalVariables[name] = value
    else
        self.callStack:SetTemporaryVariable(name, value, contextIndex)
    end
end

function VariableState:ResolveVariablePointer(varPointer)
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

function VariableState:GetContextIndexOfVariableNamed(varName)
    if self:GlobalVariableExistsWithName(varName) then
        return 1
    end

    return self.callStack:currentElementIndex()
end

function VariableState:__tostring()
    return "VariableState"
end

return VariableState
