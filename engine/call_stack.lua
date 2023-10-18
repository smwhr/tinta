local classic = import('libs.classic')
local lume = import('libs.lume')

local Path = import('values.path')
local PushPopType = import('constants.push_pop_type')

local Pointer = import('engine.pointer')

---@class CallStackThread
local CallStackThread = classic:extend()

function CallStackThread:new()
    self.callStack = {}
    self.threadIndex = 0
    self.previousPointer = Pointer:Null()
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

function CallStackThread:__tostring()
    return "CallStackThread"
end

---@class CallStackElement
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
    local toCopy = CallStack()
    toCopy.threads = {}

    for _, otherThread in pairs(self.threads) do
        table.insert(toCopy.threads, otherThread:Copy())
    end
    toCopy.threadCounter = self.threadCounter
    toCopy.startOfRoot = self.startOfRoot

    return toCopy
end


function CallStack:Reset()
    self.threads = {}

    newThread = CallStackThread()
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


function CallStack:__tostring()
    return "CallStack"
end


return CallStack
