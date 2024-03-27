---@class CallStack
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
        contextIndex = self:currentElementIndex() + 1
    end

    local contextElement = self:callStack()[contextIndex - 1]

    local varValue = contextElement.temporaryVariables[name]

    if varValue ~= nil then
        return varValue
    else
        return nil
    end
end

function CallStack:SetTemporaryVariable(name, value, declareNew, contextIndex)
    if contextIndex == 0 then
        contextIndex = self:currentElementIndex() + 1
    end

    local contextElement = self:callStack()[contextIndex - 1]

    if not declareNew then
        if not contextElement.temporaryVariables[name] then
            error("Could not find temporary variable to set: " .. name)
        end
    end

    local oldValue = contextElement.temporaryVariables[name]

    if oldValue ~= nil then
      ListValue:RetainListOriginsForAssignment(oldValue, value)
    end

    contextElement.temporaryVariables[name] = value
end

function CallStack:ContextForVariableNamed(name)
    if self:currentElement().temporaryVariables[name] ~= nil then
        return self:currentElementIndex() + 1
    else
        return 1
    end
end

function CallStack:ThreadWithIndex(index)
    for _,t in ipairs(self.threads) do
        if t.threadIndex == index then
            return t
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
    self.startOfRoot = Pointer:StartOf(Path:rootAncestorOf(storyContext))
end

function CallStack:__tostring()
    return "CallStack"
end


return CallStack
