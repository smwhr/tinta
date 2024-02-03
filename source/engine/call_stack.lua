local CallStackElement = classic:extend()

function CallStackElement:new(type, pointer, inExpressionEvaluation)
    self.currentPointer = pointer:Copy()
    self.inExpressionEvaluation = inExpressionEvaluation or false
    self.temporaryVariables = {}
    self.type = type
    self.evaluationStackHeightWhenPushed = 0
    self.functionStartInOutputStream = 0
end

function CallStackElement:Copy()
    local copy = CallStackElement(
        self.type, 
        self.currentPointer, 
        self.inExpressionEvaluation
    )
    copy.temporaryVariables = lume.clone(self.temporaryVariables)
    copy.evaluationStackHeightWhenPushed = self.evaluationStackHeightWhenPushed
    copy.functionStartInOutputStream = self.functionStartInOutputStream
    return copy
end

function CallStackElement:__tostring()
    return "CallStackElement"
end

local CallStackThread = classic:extend()

function CallStackThread:new()
    self.callStack = {}
    self.threadIndex = 0
    self.previousPointer = Pointer:Null()
end

function CallStackThread:FromSave(jThreadObj, storyContext)
    local newThread = CallStackThread()
    newThread.threadIndex = jThreadObj["threadIndex"]

    local jThreadCallstack = jThreadObj["callstack"]

    print(dump(jThreadObj))

    for _,jElTok in ipairs(jThreadCallstack) do
        local let jElementObj = jElTok
        local pushPopType = jElementObj["type"]
        local pointer = Pointer:Null()

        local currentContainerPathStr
        local currentContainerPathStrToken = jElementObj["cPath"]

        if currentContainerPathStrToken ~= nil then
            currentContainerPathStr = currentContainerPathStrToken
            threadPointerResult = storyContext:ContentAtPath(Path:FromString(currentContainerPathStr))
            pointer.container = threadPointerResult.container
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

local CallStack = classic:extend()

function CallStack:new(story)
    self.threadCounter = 0
    if story then
        self.startOfRoot = Pointer:StartOf(Path:rootAncestorOf(story))
        self:Reset()
    else
        self.startOfRoot = Pointer:Null()
    end
end

function CallStack:Clone()
    local toCopy = self
    local newCopy = CallStack()
    
    newCopy.threads = {}

    for _, otherThread in pairs(toCopy.threads) do
        table.insert(newCopy.threads, otherThread:Copy())
    end
    newCopy.threadCounter = toCopy.threadCounter
    newCopy.startOfRoot = toCopy.startOfRoot:Copy()

    return newCopy
end


function CallStack:Reset()
    self.threads = {}

    local newThread = CallStackThread()
    table.insert(newThread.callStack, 
                    CallStackElement(
                        PushPopType.Tunnel,
                        self.startOfRoot
                    )
                )
    table.insert(self.threads, newThread)
    self:setCurrentThread(newThread)
end


function CallStack:PushThread()
    local newThread = self:currentThread():Copy()
    self.threadCounter = self.threadCounter + 1
    newThread.threadIndex = self.threadCounter
    table.insert(self.threads, newThread)
end

function CallStack:ForkThread()
    local forkedThread = self:currentThread():Copy()
    self.threadCounter = self.threadCounter + 1
    forkedThread.threadIndex = self.threadCounter
    return forkedThread
end

function CallStack:PopThread()
    if self:canPopThread() then
        table.remove(self.threads)
    else
        error("Can't pop thread")
    end
end

function CallStack:canPopThread()
    return #self.threads > 1 and not self:elementIsEvaluateFromGame()
end

function CallStack:elementIsEvaluateFromGame()
    return self:currentElement().type == PushPopType.FunctionEvaluationFromGame
end

function CallStack:Push(type, externalEvaluationStackHeight, outputStreamLengthWithPushed)

    local element = CallStackElement(
            type, 
            self:currentElement().currentPointer, 
            false
    )

    element.evaluationStackHeightWhenPushed = externalEvaluationStackHeight or 0
    element.functionStartInOutputStream = outputStreamLengthWithPushed or 0

    table.insert(self:callStack(), element)
end

function CallStack:CanPop(type)
    if not self:canPop() then
        return false
    end
    if not type then
        return true
    end
    return self:currentElement().type == type
end

function CallStack:Pop(type)
    if self:CanPop(type) then
        table.remove(self:callStack())
    else
        error("Mismatched push/pop in Callstack")
    end
end

function CallStack:GetTemporaryVariableWithName(name, contextIndex)
    if contextIndex == 0 then
        contextIndex = #(self:callStack()) + 1
    end
        
    local contextElement = self:callStack()[contextIndex -1]

    local varValue = contextElement.temporaryVariables[name]

    if varValue ~= nil then
        return varValue
    else
        return nil
    end
end

function CallStack:SetTemporaryVariable(name, value, declareNew, contextIndex)
    contextIndex = contextIndex or #(self:callStack())

    local contextElement = self:callStack()[contextIndex]

    if not contextElement.temporaryVariables then
        contextElement.temporaryVariables = {}
    end

    if not contextElement.temporaryVariables[name] then
        if not declareNew then
            error("Could not find temporary variable to set: " .. name)
        end
    end

    local oldValue = contextElement.temporaryVariables[name]

    if oldValue ~= nil then
      ListValue:RetainListOriginsForAssignment(oldValue, value)
    end

    contextElement.temporaryVariables[name] = value

    return oldValue
end

function CallStack:ContextForVariableNamed(name)
    if self:currentElement().temporaryVariables[name] ~= nil then
        return self:currentElementIndex()
    else
        return self:callStack()[1]
    end
end

function CallStack:ThreadWithIndex(index)
    for i = 1, #self.threads do
        local thread = self.threads[i]
        if thread.threadIndex == index then
            return thread
        end
    end
    return nil
end

-- utils and accessors

function CallStack:callStack()
    return self:currentThread().callStack
end

function CallStack:elements()
    return self:callStack()
end

function CallStack:depth()
    return #(self:callStack())
end

function CallStack:currentElement()
    local thread = self.threads[#(self.threads)]
    local cs = thread.callStack
    return cs[#cs]
end

function CallStack:currentElementIndex()
    return #(self:callStack())
end

function CallStack:currentThread()
    return self.threads[#self.threads]
end

function CallStack:setCurrentThread(thread)
    self.threads = {}
    table.insert(self.threads, thread)
    self.threadCounter = #thread
end

function CallStack:canPop()
    return #(self:callStack()) > 1
end

function CallStack:save()
    local returnObject = {}
    local threads = {}
    for _, thread in pairs(self.threads) do
        table.insert(threads, thread:save())
    end
    returnObject["threads"] = threads
    returnObject["threadCounter"] = self.threadCounter
    return returnObject
end

-- CallStack:SetJsonToken
function CallStack:load(jObject, storyContext)
    self.threads = {}
    local jThreads = jObject["threads"]

    for _,jThreadTok in ipairs(jThreads) do
        local jThreadObj = jThreadTok
        local thread = CallStackThread:FromSave(jThreadObj, storyContext)
        table.insert(self.threads, thread)
    end

    self.threadCounter = jObject["threadCounter"]
    self.startOfRoot = Pointer:StartOf(Path:rootAncestorOf(storyContext.main))
end

function CallStack:__tostring()
    return "CallStack"
end


return CallStack
