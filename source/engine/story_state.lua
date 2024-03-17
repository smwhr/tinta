local StatePatch = classic:extend()

function StatePatch:new(toCopy)
    if toCopy ~= nil then
        self._globals = lume.clone(toCopy._globals)
        self._changedVariables = lume.unique(toCopy._changedVariables)
        self._visitCounts = lume.clone(toCopy._visitCounts)
        self._turnIndices = lume.clone(toCopy._turnIndices)
    else
        self._globals = {}
        self._changedVariables =  {}
        self._visitCounts = {}
        self._turnIndices = {}
    end
end

function StatePatch:TryGetGlobal(name, value)
    if name ~= nil and self._globals[name] ~= nil then
        return {result=self._globals[name], exists= true}
    end
    return {result=value, exists= false}
end

function StatePatch:SetGlobal(name, value)
    self._globals[name] = value
end

function StatePatch:AddChangedVariable(name)
    self._changedVariables = lume.unique(table.insert(self._changedVariables, name))
end

function StatePatch:TryGetVisitCount(container, count)
    if self._visitCounts[container] ~= nil then
        return {result=self._visitCounts[container], exists= true}
    end
    return {result=count, exists= false}
end

function StatePatch:SetVisitCount(container, count)
    self._visitCounts[container] = count
end

function StatePatch:TryGetTurnIndex(container, index)
    if self._turnIndices[container] ~= nil then
        return {result=self._turnIndices[container], exists= true}
    end
    return {result=index, exists= false}
end

function StatePatch:SetTurnIndex(container, index)
    self._turnIndices[container] = index
end

local StoryState = classic:extend()

function StoryState:new(story)
    self.kInkSaveStateVersion = 10;
    self.kMinCompatibleLoadVersion = 8;

    self.storySeed = math.random(100000)
    self.previousRandom = 0

    self.story = story
    self.callStack = CallStack(story)
    self.variablesState = VariablesState(self.callStack, story.listDefinitions)
    self.evaluationStack = {}
    self.visitCounts = {}
    self.turnIndices = {}
    self.currentTurnIndex = -1 -- actual -1
    
    self._patch = nil
    self.didSafeExit = false
    self.outputStream = {}
    self.outputStreamTextDirty = true
    self.outputStreamTagsDirty = true
    
    self._currentChoices = {}

    self.currentErrors = {}
    self.currentWarnings = {}

    self._currentText = nil
    self._currentTags = nil

    self.divertedPointer = Pointer:Null()

    self:GoToStart()
end

function StoryState:GoToStart()
    self.callStack:currentElement().currentPointer = Pointer:StartOf(
            self.story:mainContentContainer()
    )
end


function StoryState:currentText()
    if self.outputStreamTextDirty then
        local sb = {}
        local inTag = false
        for i = 1, #self.outputStream do
            local outputObj = self.outputStream[i]
            if(outputObj:is(StringValue)) then
                if not inTag then
                    table.insert(sb, outputObj.value)
                end
            end

            if(outputObj:is(ControlCommand)) then
                if outputObj.value == ControlCommandType.BeginTag then
                    inTag = true
                elseif outputObj.value == ControlCommandType.EndTag then
                    inTag = false
                end
            end
        end
        self._currentText = self:CleanOutputWhitespace(table.concat(sb))
        self.outputStreamTextDirty = false
    end
    return self._currentText
end

function StoryState:currentTags()
    if self.outputStreamTagsDirty then
        self._currentTags = {}
        local inTag = false
        local sb = {}
        for _, outputObj in pairs(self.outputStream) do
            if outputObj:is(ControlCommand) then
                local controlCommand = outputObj
                if controlCommand.value == ControlCommandType.BeginTag then
                    if inTag and #sb > 0 then
                        local txt = self:CleanOutputWhitespace(table.concat(sb))
                        table.insert(self._currentTags, txt)
                        sb = {}
                    end
                    inTag = true
                elseif controlCommand.value == ControlCommandType.EndTag then
                    if #sb > 0 then
                        local txt = self:CleanOutputWhitespace(table.concat(sb))
                        table.insert(self._currentTags, txt)
                        sb = {}
                    end
                    inTag = false
                end

            elseif inTag then
                if outputObj:is(StringValue) then
                    table.insert(sb, outputObj.value)
                end
            elseif outputObj:is(Tag) and #outputObj.text > 0 then
                table.insert(self._currentTags, outputObj.text)
            end
        end
    end
    return self._currentTags
end

function StoryState:currentPointer()
    return self.callStack:currentElement().currentPointer
end

function StoryState:setCurrentPointer(pointer)
    self.callStack:currentElement().currentPointer = pointer:Copy()
end

function StoryState:previousPointer()
    return self.callStack:currentThread().previousPointer
end

function StoryState:setPreviousPointer(pointer)
    self.callStack:currentThread().previousPointer = pointer:Copy()
end

function StoryState:ResetOutput() --add parameter when needed
    self.outputStream = {}
    self:OutputStreamDirty()
end

function StoryState:PassArgumentsToEvaluationStack(args)
    if args ~= nil then
        for _,a in ipairs(args) do
            if not (
                type(a) == "number" or
                type(a) == "string" or 
                type(a) == "boolean"
            ) then
                error("ink arguments when calling EvaluateFunction / ChoosePathStringWithParameters must be number, string, bool. Argument was " .. dump(a))
            end
    
            self:PushEvaluationStack(CreateValue(a))
        end
    end
end

function StoryState:OutputStreamDirty()
    self.outputStreamTextDirty = true
    self.outputStreamTagsDirty = true
end

function StoryState:PushToOutputStream(obj)
    local text = inkutils.asOrNil(obj, StringValue)
    if text then
        local listText = TrySplittingHeadTailWhitespace(text)
        if listText ~= nil then
            for _, textObj in pairs(listText) do
                self:PushToOutputStreamIndividual(textObj)
            end
            self:OutputStreamDirty()
            return
        end
    end
    self:PushToOutputStreamIndividual(obj)
    self:OutputStreamDirty()
end 

function StoryState:PopFromOutputStream(count)
    self.outputStream = lume.slice(self.outputStream, 1, #self.outputStream - count)
    self:OutputStreamDirty()
end

function StoryState:PushToOutputStreamIndividual(obj)
    local glue = inkutils.asOrNil(obj, Glue)
    local text = inkutils.asOrNil(obj, StringValue)
    
    local includeInOutput = true
    if glue then
        self:TrimNewlinesFromOutputStream()
        includeInOutput = true
    elseif text then
        local functionTrimIndex = 0
        local currEl = self.callStack:currentElement()
        if currEl.type == PushPopType.Function then
            functionTrimIndex = currEl.functionStartInOutputStream
        end

        local glueTrimIndex = 0
        for i = #self.outputStream, 1, -1 do
            local o = self.outputStream[i]
            if o:is(Glue) then
                glueTrimIndex = i;
                break
            end
            if o:is(ControlCommand) and o.value == ControlCommandType.BeginString  then
                if i >= functionTrimIndex  then
                    functionTrimIndex = 0
                end
                break
            end
        end
        trimIndex = 0
        if glueTrimIndex ~= 0 and functionTrimIndex  ~= 0 then
            trimIndex = math.min(glueTrimIndex, functionTrimIndex )
        elseif glueTrimIndex ~= 0 then
            trimIndex = glueTrimIndex
        else
            trimIndex = functionTrimIndex
        end

        if trimIndex ~= 0 then
            if text.isNewline then
                includeInOutput = false
            elseif text:isNonWhitespace() then
                if glueTrimIndex ~=0 then self:RemoveExistingGlue() end
                if functionTrimIndex ~= 0 then
                    local callStackElements = self.callStack:elements()
                    for i = #callStackElements, 1, -1 do
                        local el = callStackElements[i]
                        if el.type == PushPopType.Function then
                            el.functionStartInOutputStream = 0
                        else
                            break
                        end
                        
                    end
                end

            end
        elseif text.isNewline then
            if self:outputStreamEndsInNewline() or not self:outputStreamContainsContent() then
                includeInOutput = false
            end
        end
    end

    if includeInOutput then
        table.insert(self.outputStream, obj)
        self:OutputStreamDirty()
    end
end

function StoryState:inStringEvaluation()
    for i = #self.outputStream, 1, -1 do
        local cmd = self.outputStream[i]
        if cmd:is(ControlCommand) and cmd.value == ControlCommandType.BeginString then
            return true
        end
    end
    return false
end

function StoryState:outputStreamEndsInNewline()
    if #self.outputStream > 0 then
        for i = #self.outputStream, 1, -1 do
            local obj = self.outputStream[i]
            if obj:is(ControlCommand) then break end
            if obj:is(StringValue) then
                if obj.isNewline then return true
                elseif obj:isNonWhitespace() then break end
            end
        end
    end
    return false
end

function StoryState:outputStreamContainsContent()
    for _,c in ipairs(self.outputStream) do
        if c:is(StringValue) then return true end
    end
    return false
end

function StoryState:TrimNewlinesFromOutputStream()
    local removeWhitespaceFrom = 0
    
    local i = #self.outputStream

    while i >= 1 do
        local obj = self.outputStream[i]
        if obj:is(ControlCommand) or (
            obj:is(StringValue) and obj:isNonWhitespace()
        ) then
            break
        elseif obj:is(StringValue) and obj.isNewline then
            removeWhitespaceFrom = i
        end
        i = i - 1
    end

    if removeWhitespaceFrom >= 1 then
        i = removeWhitespaceFrom
        while i <= #self.outputStream do
            local obj = self.outputStream[i]
            if obj:is(StringValue) then
                table.remove(self.outputStream, i)
            else
                i = i+1
            end
        end
    end
    
    self:OutputStreamDirty()
end

function StoryState:TrimWhitespaceFromFunctionEnd()
    local functionStartPoint = self.callStack:currentElement().functionStartInOutputStream
    if functionStartPoint == 0 then
        functionStartPoint = 1
    end

    for i = #self.outputStream, functionStartPoint + 1, -1 do
        local obj = self.outputStream[i]
        if obj:is(StringValue) then
            if obj:is(ControlCommand) then break end
            if obj.isNewline or obj.isInlineWhiteSpace then
                table.remove(self.outputStream, i)
                self:OutputStreamDirty()
            else
                break
            end
        end
    end
end

function StoryState:PopCallStack()
    if self.callStack:currentElement().type == PushPopType.Function then
        self:TrimWhitespaceFromFunctionEnd()
    end

    self.callStack:Pop(popType);
end

function StoryState:SetChosenPath(path, incrementingTurnIndex)
    self._currentChoices = {}
    local newPointer = self.story:PointerAtPath(path)
    if not newPointer:isNull() and newPointer.index == 0 then newPointer.index = 1 end
    self:setCurrentPointer(newPointer)

    if(incrementingTurnIndex) then
        self.currentTurnIndex = self.currentTurnIndex + 1
    end
end

function StoryState:RemoveExistingGlue()
    for i = #self.outputStream, 1, -1 do
        local obj = self.outputStream[i]
        if obj:is(Glue) then
            table.remove(self.outputStream, i)
        elseif obj:is(ControlCommand) then
            break
        end
    end
    self:OutputStreamDirty()
end


function StoryState:canContinue()
    return not (self:currentPointer():isNull())  
            and not self:hasError()
end

function StoryState:hasError()
    return #self.currentErrors > 0
end

function StoryState:hasWarning()
    return #self.currentWarnings > 0
end

function StoryState:currentChoices()
    if self:canContinue() then
        return {}
    else
        return self._currentChoices
    end
end

function StoryState:generatedChoices()
    return self._currentChoices
end

function StoryState:VisitCountForContainer(container)
    if not container.visitsShouldBeCounted then
        error("The story may need to be compiled with countAllVisits")
    end

    if self._patch ~= nil then
        local count = self._patch:TryGetVisitCount(container, 0)
        if count.exists then return count.result end
    end

    local containerPathStr = Path:of(container):componentsString()
    local count = self.visitCounts[containerPathStr]
    if count ~= nil then
        return count
    else
        return 0
    end
end
function StoryState:IncrementVisitCountForContainer(container)
    if self._patch ~= nil then
        local currCount = self:VisitCountForContainer(container)
        currCount = currCount + 1
        self._patch:SetVisitCount(container, currCount)
        return
    end

    local containerPathStr = Path:of(container):componentsString()
    local count = self.visitCounts[containerPathStr]
    if count ~= nil then
        self.visitCounts[containerPathStr] = count + 1
    else
        self.visitCounts[containerPathStr] = 1
    end
end
function StoryState:RecordTurnIndexVisitToContainer(container)
    if self._patch ~= nil then
        self._patch:SetTurnIndex(container, self.currentTurnIndex)
        return
    end

    local containerPathStr = Path:of(container):componentsString()
    self.turnIndices[containerPathStr] = self.currentTurnIndex
end

function StoryState:TurnsSinceForContainer(container)
    if not container.turnIndexShouldBeCounted then
        error("The story may need to be compiled with countAllVisits")
    end

    if self._patch ~= nil then
        local index = self._patch:TryGetTurnIndex(container, 0)
        if index.exists then return index.result end
    end

    local containerPathStr = Path:of(container):componentsString()
    local index = self.turnIndices[containerPathStr]
    if index ~= nil then
        return self.currentTurnIndex - index
    else
        return -1 -- true -1
    end
end

function StoryState:PopEvaluationStack(numberOfObjects)
    if numberOfObjects == nil then
        local obj = table.remove(self.evaluationStack)
        return obj or nil
    end
    if numberOfObjects > #self.evaluationStack then
        error("trying to pop too many objects")
    end
    local popped = {}
    for i = 1, numberOfObjects do
        table.insert(popped, 1, table.remove(self.evaluationStack))
    end
    return popped
end

function StoryState:PushEvaluationStack(obj)
    local listValue = inkutils.asOrNil(obj, ListValue)
    if listValue then
        local rawList = listValue.value

        if rawList:originNames() ~= nil then
            rawList.origins = {}

            for _,n in ipairs(rawList:originNames()) do
                local def = self.story.listDefinitions:TryListGetDefinition(n, nil)
                if lume.find(rawList.origins, def.result) == nil then
                    table.insert(rawList.origins, def.result)
                end
            end
        end
    end
    table.insert(self.evaluationStack, obj)
end

function StoryState:PeekEvaluationStack()
    return self.evaluationStack[#self.evaluationStack]
end

function StoryState:ForceEnd()
    self.callStack:Reset()

    self._currentChoices = {}

    self:setCurrentPointer(Pointer:Null());
    self:setPreviousPointer(Pointer:Null());

    self.didSafeExit = true;
end

function StoryState:inExpressionEvaluation()
    return self.callStack:currentElement().inExpressionEvaluation
end
function StoryState:setInExpressionEvaluation(value)
    self.callStack:currentElement().inExpressionEvaluation = value
end

function StoryState:TryExitFunctionEvaluationFromGame()
    local currEl = self.callStack:currentElement()
    if currEl.type == PushPopType.FunctionEvaluationFromGame then
        self:setCurrentPointer(Pointer:Null())
        self.didSafeExit = true;
        return true
    end
    return false
end


function StoryState:__tostring()
    return "StoryState"
end

function StoryState:CleanOutputWhitespace(str)
    local sb = {}
    local currentWhitespaceStart = 0
    local startOfLine = 0

    for i=1, #str do
        local c = str:sub(i,i)
        local isInlineWhiteSpace = c == " " or c == "\t"
        if isInlineWhiteSpace and currentWhitespaceStart == 0 then
            currentWhitespaceStart = i
        end
        if not isInlineWhiteSpace then
            if (
                c ~= "\n"
                and currentWhitespaceStart > 1
                and currentWhitespaceStart ~= startOfLine
            ) then
                table.insert(sb, " ")
            end
            currentWhitespaceStart = 0
        end

        if c == "\n" then startOfLine = i + 1 end

        if not isInlineWhiteSpace then
            table.insert(sb, c)
        end
    end
    return table.concat(sb)
end

function TrySplittingHeadTailWhitespace(single)
    local str = single.value
    
    local headFirstNewlineIdx = 0
    local headLastNewlineIdx = 0
    for i = 1, #str do
        local c = str:sub(i,i)
        if c == "\n" then
            if headFirstNewlineIdx == 0 then headFirstNewlineIdx = i end
            headLastNewlineIdx = i
        elseif c == " " or c == "\t " then
            --continuee
        else 
            break
        end
    end
    
    local tailLastNewlineIdx = 0
    local tailFirstNewlineIdx = 0
    for i = #str, 1, -1 do
        local c = str:sub(i,i)
        if c == "\n" then
            if tailLastNewlineIdx == 0 then tailLastNewlineIdx = i end
            tailFirstNewlineIdx = i
        elseif c == " " or c == "\t " then
            --continuee
        else 
            break
        end
    end

    if headFirstNewlineIdx == 0 and tailLastNewlineIdx == 0 then return nil end

    local listTexts = {}
    local innerStrStart = 0
    local innerStrEnd = #str

    if headFirstNewlineIdx ~= 0 then
        if headFirstNewlineIdx > 1 then
            local leadingSpaces = StringValue(
                str:sub(1, headFirstNewlineIdx)
            )
            table.insert(listTexts, leadingSpaces)
        end
        table.insert(listTexts, StringValue("\n"))
        innerStrStart = headLastNewlineIdx + 1
    end

    if tailLastNewlineIdx ~= 0 then
        innerStrEnd = tailFirstNewlineIdx
    end

    if innerStrEnd > innerStrStart then
        local innertStrText = StringValue(
            str:sub(innerStrStart, innerStrEnd)
        ) 
        table.insert(listTexts, innertStrText)
    end

    if tailLastNewlineIdx ~= 0 and tailFirstNewlineIdx > headLastNewlineIdx then
        list.insert(listTexts, StringValue("\n"))
        if tailLastNewlineIdx < #str then
            local numSpaces = #str - tailLastNewlineIdx - 1
            local trailingSpaces = StringValue(
                str:sub(
                    tailLastNewlineIdx + 1,
                    tailLastNewlineIdx + 1 + numSpaces
                )
            )
            table.insert(listTexts, trailingSpaces)
        end
    end

    return listTexts
end

function StoryState:CopyAndStartPatching()
    local copy = StoryState(self.story)
    copy._patch = StatePatch(self._patch)
    copy.callStack = self.callStack:Clone()

    for _, c in pairs(self._currentChoices) do
        table.insert(copy._currentChoices, c)
    end
    for _, o in pairs(self.outputStream) do
        table.insert(copy.outputStream, o)
    end
    copy:OutputStreamDirty()

    if self:hasError() then
        for _, e in pairs(self.currentErrors) do
            table.insert(copy.currentErrors, e)
        end
    end
    if self:hasWarning() then
        for _, w in pairs(self.currentWarnings) do
            table.insert(copy.currentWarnings, w)
        end
    end

    copy.variablesState = self.variablesState
    copy.variablesState.callStack = copy.callStack
    copy.variablesState.patch = copy._patch;

    for _, el in pairs(self.evaluationStack) do
        table.insert(copy.evaluationStack, el)
    end

    if not self.divertedPointer:isNull() then
        copy.divertedPointer = self.divertedPointer:Copy()
    end

    copy:setPreviousPointer(self:previousPointer():Copy())
    copy.visitCounts = self.visitCounts
    copy.turnIndices = self.turnIndices

    copy.currentTurnIndex = self.currentTurnIndex
    copy.storySeed = self.storySeed
    copy.previousRandom = self.previousRandom

    copy.didSafeExit = self.didSafeExit

    return copy
end

function StoryState:RestoreAfterPatch()
    self.variablesState.callStack = self.callStack;
    self.variablesState.patch = self._patch;
end

function StoryState:ApplyAnyPatch()
    if self._patch == nil then return end
    self.variablesState:ApplyPatch()

    for key, value in pairs(self._patch._visitCounts) do
        self:ApplyCountChanges(key, value, true)
    end
    for key, value in pairs(self._patch._turnIndices) do
        self:ApplyCountChanges(key, value, false)
    end
    self._patch = nil
end

function StoryState:ApplyCountChanges(container, newCount,isVisit)
    local containerPathStr = Path:of(container):componentsString()
    if isVisit then
        self.visitCounts[containerPathStr] = newCount
    else
        self.turnIndices[containerPathStr] = newCount
    end
end

function StoryState:save()
    local save = {}
    save["flows"] = {["DEFAULT_FLOW"] = self:saveFlow()}
        
    save["variablesState"] = self.variablesState:save()
    save["evalStack"] = serialization.WriteListRuntimeObjs(self.evaluationStack)

    if not self.divertedPointer:isNull() then
        save["currentDivertTarget"] = Path:of(self.divertedPointer):componentsString()
    end
    
    save["visitCounts"] = serialization.WriteIntDictionary(self.visitCounts)
    save["turnIndices"] = serialization.WriteIntDictionary(self.turnIndices)
    save["turnIdx"] = self.currentTurnIndex
    save["storySeed"] = self.storySeed
    save["previousRandom"] = self.previousRandom
    save["inkSaveVersion"] = self.kInkSaveStateVersion
    save["inkFormatVersion"] = self.story.inkVersionCurrent
    
    return save
end

function StoryState:saveFlow()
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

function StoryState:load(jObject)
    local jSaveVersion = jObject["inkSaveVersion"]
    if jSaveVersion == nil or jSaveVersion < self.kMinCompatibleLoadVersion then
        error("Ink save format isn't compatible with the current version")
    end

    local flow = jObject["flows"]["DEFAULT_FLOW"]

    self.callStack:load(flow["callstack"], self.story)
    self.outputStream = serialization.JArrayToRuntimeObjList(flow["outputStream"])
    self._currentChoices = serialization.JArrayToRuntimeObjList(flow["currentChoices"])
    local jChoiceThreadsObj = flow["choiceThreads"]
    if jChoiceThreadsObj ~= nil then
        self:LoadChoiceThreads(jChoiceThreadsObj, self.story)
    else
        self.outputStream = {}
        self._currentChoices = {}
    end
    self:OutputStreamDirty()
    self._aliveFlowNamesDirty = true

    self.variablesState:load(jObject["variablesState"])
    self.variablesState.callStack = self.callStack

    self.evaluationStack = serialization.JArrayToRuntimeObjList(jObject["evalStack"])

    local currentDivertTargetPath = jObject["currentDivertTarget"]
    if currentDivertTargetPath ~= nil then
        local divertPath = Path:FromString(currentDivertTargetPath)
        self.divertedPointer = self.story:PointerAtPath(divertPath)
    end

    self.visitCounts = jObject["visitCounts"]
    self.turnIndices = jObject["turnIndices"]
    self.currentTurnIndex = jObject["turnIdx"]
    self.storySeed = jObject["storySeed"]
    self.previousRandom = jObject["previousRandom"]
end

-- LoadFlowChoiceThreads
function StoryState:LoadChoiceThreads(jChoiceThreads, story)
    for _,choice in ipairs(self._currentChoices) do
        local foundActiveThread = self.callStack:ThreadWithIndex(
            choice.originalThreadIndex
        )
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

return StoryState
