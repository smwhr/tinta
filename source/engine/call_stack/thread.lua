---@class CallStackThread
local CallStackThread = classic:extend()

function CallStackThread:new()
    self.callStack = {}
    self.threadIndex = 1
    self.previousPointer = Pointer:Null()
end

function CallStackThread:FromSave(jThreadObj, storyContext)
    local newThread = CallStackThread()
    newThread.threadIndex = jThreadObj["threadIndex"]

    local jThreadCallstack = jThreadObj["callstack"]

    for _,jElTok in ipairs(jThreadCallstack) do
        local let jElementObj = jElTok
        local pushPopType = jElementObj["type"]
        local pointer = Pointer:Null()

        local currentContainerPathStr
        local currentContainerPathStrToken = jElementObj["cPath"]

        if currentContainerPathStrToken ~= nil then
            currentContainerPathStr = currentContainerPathStrToken
            threadPointerResult = storyContext:ContentAtPath(Path:FromString(currentContainerPathStr))

            pointer.container = threadPointerResult:container()
            pointer.index = jElementObj["idx"]

            if threadPointerResult.obj == nil then
                error("When loading state, internal story location couldn't be found: " .. currentContainerPathStr .. ". Has the story changed since this save data was created?")
            elseif threadPointerResult.approximate then
                print("When loading state, exact internal story location couldn't be found: '" .. currentContainerPathStr .. "', so it was approximated to '" .. Path:of(pointer.container):componentsString() .. "' to recover. Has the story changed since this save data was created?")
            end
        end

        local inExpressionEvaluation = jElementObj["exp"]
        local el = CallStackElement(
            pushPopType, 
            pointer, 
            inExpressionEvaluation
        )

        local temps = jElementObj["temp"]
        if temps ~= nil then
            el.temporaryVariables = serialization.JObjectToDictionaryRuntimeObjs(temps)
        else
            el.temporaryVariables = {}
        end
        table.insert(newThread.callStack, el)
    end

    local prevContentObjPath = jThreadObj["previousContentObject"]
    if prevContentObjPath ~= nil then
        local prevPath = Path:FromString(prevContentObjPath)
        newThread.previousPointer = storyContext:PointerAtPath(prevPath)
    end
    return newThread
end

function CallStackThread:Copy()
    local copy = CallStackThread()
    copy.threadIndex = self.threadIndex
    for _,e in pairs(self.callStack) do
        table.insert(copy.callStack, e:Copy())
    end
    copy.previousPointer = self.previousPointer:Copy()
    return copy
end

function CallStackThread:save()
    local returnObject = {}
    local callstack = {}

    for _, el in ipairs(self.callStack) do
        local inner = {}

        if not el.currentPointer:isNull() then
            inner["cPath"] = Path:of(el.currentPointer.container):componentsString()
            inner["idx"] = el.currentPointer.index
        end

        inner["exp"] = el.inExpressionEvaluation
        inner["type"] = el.type

        if lume.count(el.temporaryVariables) > 0 then
            inner["temp"] = serialization.WriteDictionaryRuntimeObjs(el.temporaryVariables)
        end

        table.insert(callstack, inner)
    end

    returnObject["callstack"] = callstack

    returnObject["threadIndex"] = self.threadIndex

    if not self.previousPointer:isNull() then
        local resolvedPointer = self.previousPointer:Resolve()
        returnObject["previousContentObject"] = Path:of(resolvedPointer):componentsString()
    end

    return returnObject
end

function CallStackThread:__tostring()
    return "CallStackThread"
end

return CallStackThread