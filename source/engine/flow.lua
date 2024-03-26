---@class Flow
local Flow = classic:extend()

function Flow:new(name, story, jObject)
    self.name = name;
    if jObject ~= nil then
        self.outputStream = serialization.JArrayToRuntimeObjList(jObject["outputStream"])
        self._currentChoices = serialization.JArrayToRuntimeObjList(jObject["currentChoices"])
        self.callStack = CallStack(story)
        self.callStack:load(jObject["callstack"], story)
        self:LoadFlowChoiceThreads(jObject["choiceThreads"], story)
    else
        self.callStack = CallStack(story)
        self.outputStream = {}
        self._currentChoices = {}
    end
end

function Flow:saveFlow()
    local returnObject = {}
    returnObject["callstack"] = self.callStack:save()
    returnObject["outputStream"] = serialization.WriteListRuntimeObjs(self.outputStream)

    local hasChoiceThreads = false
    local addTo = returnObject
    for _,c in ipairs(self._currentChoices) do
        c.originalThreadIndex = c.threadAtGeneration.threadIndex
        if self.callStack:ThreadWithIndex(c.originalThreadIndex) == nil then
            if not hasChoiceThreads then
                hasChoiceThreads = true
                addTo = {}
            end
            addTo[c.originalThreadIndex] = c.threadAtGeneration:save()
        end
    end
    if hasChoiceThreads then
        returnObject["choiceThreads"] = addTo
    end
    local currentChoices = {}
    for _,c in ipairs(self._currentChoices) do
        table.insert(currentChoices, serialization.WriteChoice(c))
    end
    returnObject["currentChoices"] = currentChoices

    return returnObject
end


function Flow:LoadFlowChoiceThreads(jChoiceThreads, story)
    for _,choice in ipairs(self._currentChoices) do
        local foundActiveThread = self.callStack:ThreadWithIndex(choice.originalThreadIndex)
        if foundActiveThread ~= nil then
            choice.threadAtGeneration = foundActiveThread:Copy()
        else
            if jChoiceThreads[choice.originalThreadIndex] == nil then
                error("Could not find " .. choice.originalThreadIndex .. " in " .. dump(jChoiceThreads))
            end
            local jSavedChoiceThread = jChoiceThreads[choice.originalThreadIndex]
            choice.threadAtGeneration = CallStackThread:FromSave(jSavedChoiceThread, story)
        end
    end
end

return Flow