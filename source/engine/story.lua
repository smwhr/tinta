import("../engine/ink_header")

---@class Story
---@field state StoryState
local Story = classic:extend()

function Story:new(book)
    self._recursiveContinueCount = 0
    self.inkVersionCurrent = 21;
    self.listDefinitions = serialization.JTokenToListDefinitions(book.listDefs)
    self._mainContentContainer = serialization.JTokenToRuntimeObject(book.root)
    self:ResetState()
    self._externals = {}
    self.allowExternalFunctionFallbacks = true

    self.prevContainers = {}
    self._temporaryEvaluationContainer = nil

    self._stateSnapshotAtLastNewline = nil
    self.asyncSaving = false
    self._asyncContinueActive = false
end

function Story:mainContentContainer()
    if self._temporaryEvaluationContainer then
        return self._temporaryEvaluationContainer
    else
        return self._mainContentContainer
    end
end

---Check whether more content is available if you were to call `Continue()` - i.e.
---are we mid story rather than at a choice point or at the end.
---@return boolean _  if it's possible to call `Continue()`.
function Story:canContinue()
    return self.state:canContinue()
end

function Story:asyncContinueComplete()
    return not self._asyncContinueActive
end

function Story:currentText()
    self:IfAsyncWeCant("call currentText since it's a work in progress")
    return self.state:currentText()
end
function Story:currentTags()
    return self.state:currentTags()
end

function Story:currentChoices()
    local choices = {}
    for _,c in ipairs(self.state:currentChoices()) do
        if not c.isInvisibleDefault then
            c.index = #choices + 1
            table.insert(choices, c)
        end
    end
    return choices
end

function Story:currentErrors()
    return self.state:currentErrors()
end

function Story:currentWarnings()
    return self.state:currentWarnings()
end

function Story:currentFlowName()
    return self.state.currentFlowName
end

function Story:currentFlowIsDefaultFlow()
    return self.state:currentFlowIsDefaultFlow()
end

function Story:aliveFlowNames()
    return self.state:aliveFlowNames()
end



function Story:ContinueAsync(millisecsLimitAsync)
    if not self._hasValidatedExternals then
        self:ValidateExternalBindings()
    end
    self:ContinueInternal(millisecsLimitAsync)
end

---Continue the story for one line of content, if possible.
---If you're not sure if there's more content available, for example if you
---want to check whether you're at a choice point or at the end of the story,
---you should call `canContinue` before calling this function.
---@return string _ The line of text content.
function Story:Continue()
    self:ContinueInternal(0)
    return self:currentText();
end

---@private
function Story:ContinueInternal(millisecsLimitAsync)

    millisecsLimitAsync = millisecsLimitAsync or 0
    isAsyncTimeLimited = millisecsLimitAsync > 0

    self._recursiveContinueCount = self._recursiveContinueCount + 1

    if not self._asyncContinueActive then
        self._asyncContinueActive = isAsyncTimeLimited

        if not self:canContinue() then
            error("Can't continue - should check canContinue() before calling Continue")
        end
        self.state.didSafeExit = false;
        self.state:ResetOutput();

        if self._recursiveContinueCount == 1 then
            self.state.variablesState:batchObservingVariableChanges(true)
        end
    end

    durationStop = inkutils.resetElapsedTime()

    local outputStreamEndsInNewline = false
    repeat
        outputStreamEndsInNewline = self:ContinueSingleStep();
        if outputStreamEndsInNewline then break end

        -- print(inkutils.getElapsedTime())
        if 
            self._asyncContinueActive 
            and inkutils.getElapsedTime() > millisecsLimitAsync
        then
            break
        end
        
    until not self:canContinue()

    if outputStreamEndsInNewline or not self:canContinue() then

        if self._stateSnapshotAtLastNewline ~= nil then
            self:RestoreStateSnapshot()
        end

        if not self:canContinue() then
            if self.state:callStack():canPopThread() then
                error("Thread available to pop, threads should always be flat by the end of evaluation?")
            end
            if (    #self.state:generatedChoices() == 0
                and not self.state.didSafeExit
                and self._temporaryEvaluationContainer == nil
            ) then
                if self.state:callStack():CanPop(PushPopType.Tunnel) then
                    error("unexpectedly reached end of content. Do you need a '->->' to return from a tunnel?")
                elseif self.state:callStack():CanPop(PushPopType.Function) then
                    error("unexpectedly reached end of content. Do you need a '~ return'?")
                elseif not self.state:callStack():canPop() then
                    error("ran out of content. Do you need a '-> DONE' or '-> END'?")
                else
                    error("unexpectedly reached end of content for unknown reason. Please debug compiler!")
                end
            end
        end
        self.state.didSafeExit = false
        self._sawLookaheadUnsafeFunctionAfterNewLine = false

        if self._recursiveContinueCount == 1 then
            self.state.variablesState:batchObservingVariableChanges(false)
        end

        self._asyncContinueActive = false
    end

    self._recursiveContinueCount = self._recursiveContinueCount - 1

    --TODO : Error handlers (Story.cs 523)
end

function Story:IfAsyncWeCant(activityStr)
    if self._asyncContinueActive then
        error("Can't " .. activityStr .. ". Story is in the middle of a ContinueAsync(). Make more ContinueAsync() calls or a single Continue() call beforehand.")
    end
end

function Story:ContinueSingleStep()
    self:Step()

    if not self:canContinue() and not self.state:callStack():elementIsEvaluateFromGame() then
        self:TryFollowDefaultInvisibleChoice()
    end

    if not self.state:inStringEvaluation() then

        if self._stateSnapshotAtLastNewline ~= nil then
            local change = self:CalculateNewlineOutputStateChange(
                self._stateSnapshotAtLastNewline:currentText(),
                self.state:currentText(),
                #self._stateSnapshotAtLastNewline:currentTags(),
                #self.state:currentTags()
            )
            if change == "ExtendedBeyondNewline" then
                self:RestoreStateSnapshot()
                return true
            elseif change == "NewlineRemoved" then
                self:DiscardSnapshot()
            end
        end
        
        if self.state:outputStreamEndsInNewline() then
            if self:canContinue() then
                if self._stateSnapshotAtLastNewline == nil then
                    self:StateSnapshot()
                end
            else
                self:DiscardSnapshot()
            end
        end
    end
    return false
end

function Story:CalculateNewlineOutputStateChange(prevText, currText, prevTagCount, currTagCount)
    local newlineStillExists = (
            #currText >= #prevText
        and #prevText > 0
        and currText:sub(#prevText, #prevText) == "\n"
    )

    if (
          prevTagCount == currTagCount
      and #prevText == #currText
      and newlineStillExists
    ) then
      return "NoChange"
    end

    if not newlineStillExists then return "NewlineRemoved" end

    if currTagCount > prevTagCount then
        return "ExtendedBeyondNewline"
    end
    

    for i=#prevText, #currText do
        local c = currText:sub(i,i)
        if c ~= " " or c ~= "\t" then return "ExtendedBeyondNewline" end
    end
    return "NoChange"
end

function Story:Step()
    local shouldAddToStream = true
    local pointer = self.state:currentPointer():Copy()

    if pointer:isNull() then
        return
    end

    -- Container
    containerToEnter = inkutils.asOrNil(pointer:Resolve(), Container)

    while containerToEnter do
        self:VisitContainer(containerToEnter, true)
        if #containerToEnter.content == 0 then break end

        pointer = Pointer:StartOf(containerToEnter)

        containerToEnter = inkutils.asOrNil(pointer:Resolve(), Container)
    end

    self.state:setCurrentPointer(pointer:Copy())

    local currentContentObj = pointer:Resolve()

    local isLogicOrFlowControl = self:PerformLogicAndFlowControl(currentContentObj)

    if self.state:currentPointer():isNull() then
        return
    end

    if isLogicOrFlowControl then
        shouldAddToStream = false
    end

    local choicePoint = inkutils.asOrNil(currentContentObj, ChoicePoint)
    if choicePoint then
        local choice = self:ProcessChoice(choicePoint)
        if choice then
            table.insert(self.state:generatedChoices(), choice)
        end
        currentContentObj = nil
        shouldAddToStream = false
    end

    if currentContentObj and currentContentObj:is(Container) then
        shouldAddToStream = false
    end

    if shouldAddToStream then
        local varPointer = inkutils.asOrNil(currentContentObj, VariablePointerValue)
        if varPointer then
            if varPointer.contextIndex == 0 then
                local contextIdx = self.state:callStack():ContextForVariableNamed(varPointer.variableName)
                currentContentObj = VariablePointerValue(
                    varPointer.variableName,
                    contextIdx
                )
            end
        end
        if self.state:inExpressionEvaluation() then
            self.state:PushEvaluationStack(currentContentObj)
        else
            self.state:PushToOutputStream(currentContentObj)
        end
    end

    self:NextContent()

    local controlCmd = inkutils.asOrNil(currentContentObj, ControlCommand)
    if controlCmd then
        if controlCmd.value == ControlCommandType.StartThread then
            self.state:callStack():PushThread()
        end
    end

end

function Story:NextContent()
    self.state:setPreviousPointer(self.state:currentPointer():Copy())
    if not self.state.divertedPointer:isNull() then
        self.state:setCurrentPointer(self.state.divertedPointer:Copy())
        self.state.divertedPointer = Pointer:Null()

        self:VisitChangedContainersDueToDivert()

        if not self.state:currentPointer():isNull() then
            return
        end
    end

    local successfulPointerIncrement = self:IncrementContentPointer()
    if not successfulPointerIncrement then
        local didPop = false

        if self.state:callStack():CanPop(PushPopType.Function) then
            self.state:PopCallStack(PushPopType.Function)
            if self.state:inExpressionEvaluation() then
                self.state:PushEvaluationStack(Void())
            end

            didPop = true
        elseif self.state:callStack():canPopThread() then
            self.state:callStack():PopThread()
            didPop = true
        else
            self.state:TryExitFunctionEvaluationFromGame()
        end

        if didPop and not self.state:currentPointer():isNull() then
            self:NextContent()
        end

    end
end

function Story:VisitChangedContainersDueToDivert()
    local previousPointer = self.state:previousPointer():Copy()
    local pointer = self.state:currentPointer():Copy()

    if pointer:isNull() or pointer.index == 0 then return end

    self.prevContainers = {}
    if not previousPointer:isNull() then
        local resolvedPreviousAncestor = previousPointer:Resolve()
        local prevAncestor = inkutils.asOrNil(resolvedPreviousAncestor, Container) or inkutils.asOrNil(previousPointer.container, Container)

        while prevAncestor do
            table.insert(self.prevContainers, prevAncestor)
            prevAncestor = inkutils.asOrNil(prevAncestor.parent, Container)
        end
    end

    local currentChildOfContainer = pointer:Resolve()
    
    if currentChildOfContainer == nil then return end

    local currentContainerAncestor = inkutils.asOrNil(currentChildOfContainer.parent, Container)
    local allChildrenEnteredAtStart = true

    while (
        currentContainerAncestor
        and (
               not lume.find(self.prevContainers, currentContainerAncestor)
            or currentContainerAncestor.countingAtStartOnly
        )
    ) do
        local enteringAtStart = ( 
            #currentContainerAncestor.content > 0
        and currentChildOfContainer == currentContainerAncestor.content[1]
        and allChildrenEnteredAtStart
        )

        if not enteringAtStart then allChildrenEnteredAtStart = false end

        self:VisitContainer(currentContainerAncestor, enteringAtStart)

        currentChildOfContainer = currentContainerAncestor
        currentContainerAncestor = inkutils.asOrNil(currentContainerAncestor.parent, Container)
    end

end

function Story:IncrementContentPointer()
    local successfulIncrement = true
    local pointer = self.state:callStack():currentElement().currentPointer:Copy()
    
    pointer.index = pointer.index + 1

    while pointer.index > #pointer.container.content do
        successfulIncrement = false
        
        local nextAncestor = inkutils.asOrNil(pointer.container.parent, Container)
        if nextAncestor == nil then break end

        local indexInAncestor = lume.find(nextAncestor.content, pointer.container)
        if indexInAncestor == nil then break end

        pointer = Pointer(nextAncestor, indexInAncestor)
        pointer.index = pointer.index + 1

        successfulIncrement = true
    end
    
    if not successfulIncrement then pointer = Pointer:Null() end
    
    self.state:setCurrentPointer(pointer)
    
    return successfulIncrement
end

function Story:VisitContainer(container, atStart)
    if (not container.countingAtStartOnly) or atStart then
        if container.visitsShouldBeCounted then
            self.state:IncrementVisitCountForContainer(container)
        end
        if container.turnIndexShouldBeCounted then
            self.state:RecordTurnIndexVisitToContainer(container)
        end
    end
end

function Story:ResetState()
    self:IfAsyncWeCant("ResetState")
    self.state = StoryState(self)
    local varChange = function (varName, newVal)
        self:VariableStateDidChangeEvent(varName, newVal)
    end
    self.state.variablesState.variableChangedEvent:add(varChange)
    self:ResetGlobals()
end

function Story:ResetGlobals()
    if self:mainContentContainer().namedContent["global decl"] ~= nil then
        local originalPointer = self.state:currentPointer():Copy()
        self:ChoosePath(Path:FromString("global decl"), false)
        self:ContinueInternal()
        self.state:setCurrentPointer(originalPointer)
    end
    self.state.variablesState:SnapshotDefaultGlobals();
end

function Story:SwitchFlow(flowName)
    self:IfAsyncWeCant("switch flow")
    assert(self.asyncSaving == false, "Story is already in background saving mode, can't switch flow to "..flowName)

    self.state:SwitchFlow(flowName)
end

function Story:RemoveFlow(flowName)
    self.state:RemoveFlow(flowName)
end

function Story:SwitchToDefaultFlow()
    self.state:SwitchToDefaultFlow()
end

function Story:IsTruthy(obj)
    if obj:is(BaseValue) then
        return obj:isTruthy()
    end
    return true
end

function Story:PerformLogicAndFlowControl(contentObj)
    if not contentObj then
        return false
    end

    -- Divert
    if contentObj:is(Divert) then
        local currentDivert = contentObj

        if currentDivert.isConditional then
            local conditionValue = self.state:PopEvaluationStack()
            if not self:IsTruthy(conditionValue) then
                return true
            end
        end

        if currentDivert:hasVariableTarget() then
            local varName = currentDivert.variableDivertName

            local varContents = self.state.variablesState:GetVariableWithName(varName)
            
            if not varContents then
                error("Tried to divert using a target from a variable that could not be found (" .. varName .. ")")
            end

            if not varContents:is(DivertTarget) then
                error("Tried to divert to a target from a variable, but the variable (" .. varName .. ") didn't contain a divert target")
            end

            self.state.divertedPointer = self:PointerAtPath(varContents:targetPath())
        elseif currentDivert.isExternal then
            self:CallExternalFunction(currentDivert:targetPathString(), currentDivert.externalArgs)
        else
            self.state.divertedPointer = currentDivert:targetPointer():Copy()
        end

        if currentDivert.pushesToStack then
            self.state:callStack():Push(
                currentDivert.stackPushType,
                nil,
                #self.state:outputStream()
            )
        end

        if self.state.divertedPointer:isNull() and not currentDivert.isExternal then
           error("Divert resolution failed") 
        end
        
        return true

    -- Command Control
    elseif contentObj:is(ControlCommand) then
        local evalCommand = contentObj;

        if     evalCommand.value == ControlCommandType.EvalStart then
            self.state:setInExpressionEvaluation(true)

        elseif evalCommand.value == ControlCommandType.EvalEnd then
            self.state:setInExpressionEvaluation(false)

        elseif evalCommand.value == ControlCommandType.EvalOutput then
            if #self.state.evaluationStack > 0 then
                local output = self.state:PopEvaluationStack()
                if not output:is(Void) then
                    local text = StringValue(tostring(output))
                    self.state:PushToOutputStream(text)
                end
            end
        elseif evalCommand.value == ControlCommandType.NoOp then
            -- Do nothing
        elseif evalCommand.value == ControlCommandType.Duplicate then
            self.state:PushEvaluationStack(self.state:PeekEvaluationStack())

        elseif evalCommand.value == ControlCommandType.PopEvaluatedValue then
            self.state:PopEvaluationStack()

        elseif evalCommand.value == ControlCommandType.PopFunction
        or     evalCommand.value == ControlCommandType.PopTunnel then
            local popType = nil
            if evalCommand.value == ControlCommandType.PopFunction then
                popType = PushPopType.Function
            else
                popType = PushPopType.Tunnel
            end

            local overrideTunnelReturnTarget = nil
            if popType == PushPopType.Tunnel then
                local popped = self.state:PopEvaluationStack()
                overrideTunnelReturnTarget = inkutils.asOrNil(popped, DivertTarget)
                if(not overrideTunnelReturnTarget) then
                    if not popped:is(Void) then
                        error("Expected void if ->-> doesn't override target")
                    end
                end
            end

            if self.state:TryExitFunctionEvaluationFromGame() then
                -- Do nothing
            elseif self.state:callStack():currentElement().type ~= popType or not self.state:callStack():canPop() then
                error("Mismatched push/pop in flow")
            else
                self.state:PopCallStack()
                if overrideTunnelReturnTarget then
                    self.state.divertedPointer = self:PointerAtPath(overrideTunnelReturnTarget:targetPath())
                end
            end

        elseif evalCommand.value == ControlCommandType.BeginString then
            self.state:PushToOutputStream(evalCommand)
            self.state:setInExpressionEvaluation(false)

        elseif evalCommand.value == ControlCommandType.BeginTag then
            self.state:PushToOutputStream(evalCommand)

        elseif evalCommand.value == ControlCommandType.EndTag then
            if self.state:inStringEvaluation() then
                local contentStackForTag = {}
                local outputCountConsumed = 0
                for i = #self.state:outputStream(), 1, -1 do
                    local obj = self.state:outputStream()[i]
                    outputCountConsumed = outputCountConsumed + 1
                    
                    if obj:is(ControlCommand) then
                        local command = obj
                        if command.value == ControlCommandType.BeginTag then
                            break
                        else
                            error("Unexpected control command in string evaluation output stream")
                        end
                    end
                    if obj:is(StringValue) then
                        table.insert(contentStackForTag, obj)
                    end
                end

                self.state:PopFromOutputStream(outputCountConsumed)
                local sb = {}
                for _,strVal in pairs(contentStackForTag) do
                    table.insert(sb, strVal.value)
                end
                local choiceTag = Tag(
                    self.state:CleanOutputWhitespace(table.concat(sb))
                )
                self.state:PushEvaluationStack(choiceTag)
            else
                self.state:PushToOutputStream(evalCommand)
            end



        elseif evalCommand.value == ControlCommandType.EndString then
            local contentStackForString = {}
            local contentToRetain = {}
            
            local outputCountConsumed = 0
            for i = #self.state:outputStream(), 1, -1 do
                local obj = self.state:outputStream()[i]

                outputCountConsumed = outputCountConsumed + 1
                
                if obj:is(ControlCommand) and obj.value == ControlCommandType.BeginString then
                   break
                end
                if obj:is(Tag) then
                    table.insert(contentToRetain, obj)
                end
                if obj:is(StringValue) then
                    table.insert(contentStackForString, obj)
                end
            end

            self.state:PopFromOutputStream(outputCountConsumed)

            for _, rescuedTag in ipairs(contentToRetain) do
                self.state:PushToOutputStream(rescuedTag)
            end

            contentStackForString = lume.reverse(contentStackForString)

            local sb = {}
            for _, s in ipairs(contentStackForString) do
                table.insert(sb, tostring(s.value))
            end
            
            self.state:setInExpressionEvaluation(true)
            self.state:PushEvaluationStack(StringValue(table.concat(sb)))

        elseif evalCommand.value == ControlCommandType.ChoiceCount then
            local choiceCount = #self.state:generatedChoices()
            self.state:PushEvaluationStack(IntValue(choiceCount))

        elseif evalCommand.value == ControlCommandType.Turns then
            self.state:PushEvaluationStack(IntValue(self.state.currentTurnIndex))

        elseif evalCommand.value == ControlCommandType.TurnsSince
        or     evalCommand.value == ControlCommandType.ReadCount then
            local target = self.state:PopEvaluationStack()

            if not target:is(DivertTarget) then
                local extraNote = "."
                if target:is(IntValue) then
                    extraNote = ". Did you accidentally pass a read count ('knot_name') instead of a target ('-> knot_name')?";
                end
                error(
                    "TURNS_SINCE / READ_COUNT expected a divert target (knot, stitch, label name), but saw " .. tostring(target) .. extraNote
                )
            end
            
            local divertTarget = target
            local container = inkutils.asOrNil(
                self:ContentAtPath(divertTarget:targetPath()):correctObj(),
                Container
            )
            local eitherCount = -1
            if container ~= nil then
                if evalCommand.value == ControlCommandType.TurnsSince then
                    eitherCount = self.state:TurnsSinceForContainer(container)
                else
                    eitherCount = self.state:VisitCountForContainer(container)
                end
            else
                if evalCommand.value == ControlCommandType.TurnsSince then
                    eitherCount = -1
                else
                    eitherCount = 0
                end
                
            end

            self.state:PushEvaluationStack(IntValue(eitherCount))

        elseif evalCommand.value == ControlCommandType.Random then
            local maxInt = self.state:PopEvaluationStack()
            local minInt = self.state:PopEvaluationStack()

            if not maxInt:is(IntValue) then
                error("Invalid value for minimum parameter of RANDOM(min, max)")
            end

            if not minInt:is(IntValue) then
                error("Invalid value for maximum parameter of RANDOM(min, max)")
            end

            local resultSeed = self.state.storySeed + self.state.previousRandom;
            local random = PRNG(resultSeed);

            local randomRange = maxInt.value - minInt.value + 1
            local nextRandom = random:next()
            local chosenValue = (nextRandom % randomRange) + minInt.value
            self.state:PushEvaluationStack(IntValue(chosenValue))
            
            self.state.previousRandom = nextRandom
            

        elseif evalCommand.value == ControlCommandType.SeedRandom then
            local seed = self.state:PopEvaluationStack()
            if not seed:is(IntValue) then
                error("Invalid value passed to SEED_RANDOM")
            end

            -- math.randomseed(seed.value) --just in case
            self.state.storySeed = seed.value
            self.state.previousRandom = 0

            self.state:PushEvaluationStack(Void())

        elseif evalCommand.value == ControlCommandType.VisitIndex then
            local count = self.state:VisitCountForContainer(self.state:currentPointer().container) - 1
            self.state:PushEvaluationStack(IntValue(count))

        elseif evalCommand.value == ControlCommandType.SequenceShuffleIndex then
            local shuffleIndex = self:NextSequenceShuffleIndex()
            self.state:PushEvaluationStack(IntValue(shuffleIndex))

        elseif evalCommand.value == ControlCommandType.StartThread then
            -- Done in main step function
        elseif evalCommand.value == ControlCommandType.Done then
            if self.state:callStack():canPopThread() then
                self.state:callStack():PopThread()
            else
                self.state.didSafeExit = true
                self.state:setCurrentPointer(Pointer:Null())
            end

        elseif evalCommand.value == ControlCommandType.End then
            self.state:ForceEnd()

        elseif evalCommand.value == ControlCommandType.ListFromInt then
            local intVal = inkutils.asOrNil(self.state:PopEvaluationStack(), IntValue)
            local listNameVal = self.state:PopEvaluationStack()
            if intVal == nil then
                error("Passed non-integer when creating a list element from a numerical value.")
            end
            local generatedListValue = nil
            local foundListDef = self.listDefinitions:TryListGetDefinition(listNameVal.value, nil)
            if foundListDef.exists then
                local foundItem = foundListDef.result:TryGetItemWithValue(intVal.value, ListItem:Null())
                if foundItem.exists then
                    generatedListValue = ListValue(foundItem.result, intVal.value)
                end
            else
                error( "Failed to find LIST called " .. listNameVal.value)
            end
            if generatedListValue == nil then
                generatedListValue = ListValue()
            end
            self.state:PushEvaluationStack(generatedListValue)
        elseif evalCommand.value == ControlCommandType.ListRange then
            
            local max = inkutils.asOrNil(self.state:PopEvaluationStack(), BaseValue)
            local min = inkutils.asOrNil(self.state:PopEvaluationStack(), BaseValue)

            local targetList = inkutils.asOrNil(self.state:PopEvaluationStack(), ListValue)

            if targetList == nil or min == nil or max == nil then
                error("Expected list, minimum and maximum for LIST_RANGE")
            end

            local result = targetList.value:ListWithSubRange(
                min.value, max.value
            )
            self.state:PushEvaluationStack(ListValue(result))

        elseif evalCommand.value == ControlCommandType.ListRandom then
            local listVal = inkutils.asOrNil(self.state:PopEvaluationStack(), ListValue)
            if listVal == nil then
                error("Expected list for LIST_RANDOM")
            end
            local list = listVal.value
            local newList = nil

            if list:Count() == 0 then
                newList = InkList()
            else
                local resultSeed = self.state.storySeed + self.state.previousRandom
                local random = PRNG(resultSeed)
                local nextRandom = random:next()
                local listItemIndex = nextRandom % list:Count() + 1
                local i = 0
                local chosenKey = nil
                local chosenValue = nil
                for k, v in pairs(list._inner) do
                    i = i+1
                    if i == listItemIndex then
                        chosenKey = k
                        chosenValue = v
                    end
                end
                local randomItem = {
                    Key = ListItem:fromSerializedKey(chosenKey),
                    Value = chosenValue
                }
                newList = InkList:FromOriginListName(randomItem.Key.originName, self)
                newList:Add(randomItem.Key, randomItem.Value)
                self.state.previousRandom = nextRandom
            end
            self.state:PushEvaluationStack(ListValue(newList))
        else
            error("unhandled ControlCommand: " .. evalCommand)
        end
        return true

    -- Variable Assignment
    elseif contentObj:is(VariableAssignment) then
        local varAss = contentObj
        local assignedVal = self.state:PopEvaluationStack()
        self.state.variablesState:Assign(varAss, assignedVal)
        return true
    -- Variable Reference
    elseif contentObj:is(VariableReference) then
        local varRef = contentObj
        local foundValue = nil

        if varRef.pathForCount ~= nil then
            local container = varRef:containerForCount()
            local count = self.state:VisitCountForContainer(container)
            foundValue = IntValue(count)
        else
            foundValue = self.state.variablesState:GetVariableWithName(varRef.name)
            if foundValue == nil then
                foundValue = IntValue(0)
            end
        end

        self.state:PushEvaluationStack(foundValue)
        return true
    -- Native Function Call
    elseif contentObj:is(NativeFunctionCall) then
        local func = contentObj
        local funcParams = self.state:PopEvaluationStack(func:numberOfParameters())
        local result = func:Call(funcParams)
        self.state:PushEvaluationStack(result)
        return true
    end

    -- no control content, must be ordinary content
    return false
end

function Story:ChoosePathString(path, resetCallstack, args)
    if resetCallstack == nil then
        resetCallstack = true
    end
    
    self:IfAsyncWeCant("call ChoosePathString right now")

    if resetCallstack then
        self:ResetCallstack()
    else
        if self.state:callStack():currentElement().type == PushPopType.Function then
         error("Story was running a function when you called ChoosePathString - this is almost certainly not not what you want!")
        end
    end

    self.state:PassArgumentsToEvaluationStack(args)
    self:ChoosePath(Path:FromString(path))

end

function Story:ResetCallstack()
    self:IfAsyncWeCant("ResetCallstack")
    self.state:ForceEnd()
end

function Story:ContentAtPath(path)
    return self:mainContentContainer():ContentAtPath(path)
end

function Story:KnotContainerWithName(name)
    local namedContainer = self:mainContentContainer().namedContent[name]
    return inkutils.asOrNil(namedContainer, Container)
end

function Story:PointerAtPath(path)
    if path:length() == 0 then
        return Pointer:Null()
    end

    local p = Pointer()
    local pathLengthToUse = path:length()
    if path:lastComponent() == nil then
        error("path.lastComponent is null")
    end

    local result = nil

    if path:lastComponent():isIndex() then
        pathLengthToUse = pathLengthToUse - 1
        result = self:mainContentContainer():ContentAtPath(
            path, nil, pathLengthToUse
        )
        p.container = result:container()
    else
        result = self:mainContentContainer():ContentAtPath(path);
        p.container = result:container();
    end

    return p
end

function Story:NextSequenceShuffleIndex()
    local numElementsIntVal = inkutils.asOrNil(self.state:PopEvaluationStack(), IntValue)
    if not numElementsIntVal:is(IntValue) then
        error("expected number of elements in sequence for shuffle index")
    end

    local seqContainer = self.state:currentPointer().container
    local numElements = numElementsIntVal.value
    local seqCountVal = self.state:PopEvaluationStack() --IntValue
    local seqCount = seqCountVal.value

    local loopIndex = seqCount / numElements
    local iterationIndex = seqCount % numElements + 1
    local seqPathStr = Path:of(seqContainer):componentsString()
    local sequenceHash = lume.reduce(lume.explode(seqPathStr), function(acc, comp) return acc+string.byte(comp) end, 0)
    local randomSeed = sequenceHash + loopIndex + self.state.storySeed
    local random = PRNG(randomSeed)

    local unpickedIndices = {}
    for i = 1, numElements do
        table.insert(unpickedIndices, i)
    end

    for i = 1, iterationIndex do
        local chosen = random:range(1, #unpickedIndices)
        local chosenIndex = unpickedIndices[chosen]
        table.remove(unpickedIndices, chosen)
        if i == iterationIndex then
            return chosenIndex - 1
        end
    end

    error("Should never reach here")

end

function Story:PopChoiceStringAndTags(tags)
    local choiceOnlyStrVal = self.state:PopEvaluationStack()
    while (
             #(self.state.evaluationStack) > 0 
        and  self.state:PeekEvaluationStack():is(Tag)
    ) do
        local tag = self.state:PopEvaluationStack()
        if tag:is(Tag) then table.insert(tags, tag.text) end
    end
    return choiceOnlyStrVal.value
end

function Story:ProcessChoice(choicePoint)
    local showChoice = true
    if choicePoint.hasCondition then
        local conditionValue = self.state:PopEvaluationStack()
        if not self:IsTruthy(conditionValue) then
            showChoice = false
        end
    end

    local startText = ""
    local choiceOnlyText = ""
    local tags = {}

    if choicePoint.hasChoiceOnlyContent then
        choiceOnlyText = self:PopChoiceStringAndTags(tags) or ""
    end
    if choicePoint.hasStartContent then
        startText = self:PopChoiceStringAndTags(tags) or ""
    end

    if choicePoint.onceOnly then
        local choiceTarget = choicePoint:choiceTarget()
        local visitCount = self.state:VisitCountForContainer(choiceTarget)
        if visitCount > 0 then
            showChoice = false
        end
    end

    if not showChoice then return nil end

    local choice = Choice()
    choice.targetPath = choicePoint:pathOnChoice()
    choice.sourcePath = Path:of(choicePoint):componentsString()
    choice.isInvisibleDefault = choicePoint.isInvisibleDefault
    choice.threadAtGeneration = self.state:callStack():ForkThread()
    choice.tags = lume.reverse(tags)
    choice.text = lume.trim(startText .. choiceOnlyText)

    return choice
end

function Story:ChoosePath(p, incrementingTurnIndex)
    incrementingTurnIndex = incrementingTurnIndex or true
    self.state:SetChosenPath(p, incrementingTurnIndex)
    self:VisitChangedContainersDueToDivert()
end

function Story:ChooseChoiceIndex(choiceIdx)
    choiceIdx = tonumber(choiceIdx)
    local choices = self:currentChoices()
    if choiceIdx < 1 or choiceIdx > #choices then
        error("choice out of range")
    end

    local choiceToChoose = choices[choiceIdx]

    self.state:callStack():setCurrentThread(choiceToChoose.threadAtGeneration)

    self:ChoosePath(choiceToChoose.targetPath)
end

--- Checks if a function exists.
---@return boolean  _  true if the function exists, else false.
---@param functionName string The name of the function as declared in ink.
function Story:HasFunction(functionName)
    return self:KnotContainerWithName(functionName) ~= nil
end

---Evaluates a function defined in ink. 
---@return any _  The return value as returned from the ink function with `~ return myValue`, or `nil` if nothing is returned.
---@return string textOutput the text content produced by the function via normal ink, if any.
---@param functionName string The name of the function as declared in ink.
---@param arguments table The arguments that the ink function takes, if any. Note that we don't (can't) do any validation on the number of arguments right now, so make sure you get it right!
function Story:EvaluateFunction(functionName, arguments)
    self:IfAsyncWeCant("evaluate a function")
    assert(functionName, "Function is null")
    assert(string.gsub(functionName," ","") ~= "", "Function is empty or white space.")
    
    local funcContainer = self:KnotContainerWithName(functionName)
    assert(funcContainer, "Function doesn't exist: '" .. functionName.. "'")

    local outputStreamBefore = {}
    for _,item in ipairs(self.state:outputStream()) do
        table.insert(outputStreamBefore, item)
    end

    self.state:ResetOutput(outputStreamBefore)

    self.state:StartFunctionEvaluationFromGame(funcContainer, arguments)

    local stringOutput = ""
    while self:canContinue() do
        stringOutput = stringOutput..self:Continue()
    end
    
    local result = self.state:CompleteFunctionEvaluationFromGame()

    return result, stringOutput
end

function Story:EvaluateExpression(exprContainer)
    local startCallStackHeight = #self.state:callStack().elements
    
    self.state:callStack():Push(PushPopType.Tunnel)

    self._temporaryEvaluationContainer = exprContainer

    self.state:GoToStart()

    local evalStackHeight = #self.state.evaluationStack

    self:Continue()

    self._temporaryEvaluationContainer = nil

    if (#self.state:callStack().elements > startCallStackHeight) then
        self.state:PopCallStack()
    end

    local endStackHeight = #self.state.evaluationStack
    if endStackHeight > evalStackHeight then
        return self.state:PopEvaluationStack()
    end

    return nil
end

function Story:TryGetExternalFunction(functionName)
    return self._externals[functionName]
end

function Story:CallExternalFunction(funcName, numberOfArguments)
    local fallbackFunctionContainer = nil
    local funcDef = self:TryGetExternalFunction(funcName)
    if funcDef~=nil and funcDef.lookaheadSafe == false and self.state.inStringEvaluation then
        error("External function "..funcName.." could not be called because 1) it wasn't marked as lookaheadSafe when BindExternalFunction was called and 2) the story is in the middle of string generation, either because choice text is being generated, or because you have ink like \"hello {func()}\". You can work around this by generating the result of your function into a temporary variable before the string or choice gets generated: ~ temp x = "..funcName.."()")
    end

    if funcDef~=nil and funcDef.lookaheadSafe == false and self._stateSnapshotAtLastNewline~=nil then
        self._sawLookaheadUnsafeFunctionAfterNewLine = true
        return
    end

    if funcDef == nil then
        if self.allowExternalFunctionFallbacks then
            fallbackFunctionContainer = self:KnotContainerWithName(funcName)
            assert(fallbackFunctionContainer,"Trying to call EXTERNAL function '" 
                .. funcName .. 
                "' which has not been bound, and fallback ink function could not be found.")
            self.state:callStack():Push(
                PushPopType.Function, 0, 
                #self.state:outputStream()
            )
            self.state.divertedPointer = Pointer:StartOf(fallbackFunctionContainer)
            return
        else
            error("Trying to call EXTERNAL function '" .. funcName .. 
                "' which has not been bound (and ink fallbacks disabled).")
        end
    end

    local arguments = {}
    for i = numberOfArguments, 1, -1 do
        local poppedObj = inkutils.asOrNil(self.state:PopEvaluationStack(), BaseValue)
        local valueObj = poppedObj.valueObj
        table.insert(arguments, valueObj, i)
    end

    local returnObj
    local funcResult = funcDef.func(arguments)
    if funcResult ~= nil then
        returnObj = BaseValue(funcResult)
        assert(returnObj,"Could not create ink value from returned object of type " .. type(funcResult))
    else
        returnObj = Void()
    end
    
    self.state:PushEvaluationStack(returnObj);
end

---Bind a lua function to an ink EXTERNAL function declaration.
---@param funcName string EXTERNAL ink function name to bind to.
---@param func function The lua function to bind.
---@param lookaheadSafe boolean the ink engine often evaluates further
---than you might expect beyond the current line just in case it sees 
---glue that will cause the two lines to become one. In this case it's 
---possible that a function can appear to be called twice instead of 
---just once, and earlier than you expect. If it's safe for your 
---function to be called in this way (since the result and side effect 
---of the function will not change), then you can pass 'true'. 
---Usually, you want to pass 'false', especially if you want some action 
---to be performed in game code when this function is called.
function Story:BindExternalFunction(funcName, func, lookaheadSafe)
    assert(func, "Can't bind a null function");
    self:IfAsyncWeCant("bind an external function")
    assert(self._externals[funcName]==nil, "Function '" ..funcName .. "' has already been bound.")
    self._externals[funcName] = {
        func = func,
        lookaheadSafe = lookaheadSafe
    }
end

---Remove a binding for a named EXTERNAL ink function.
---@param funcName string
function Story:UnbindExternalFunction(funcName)
    self:IfAsyncWeCant("unbind an external function")
    assert(self._externals[funcName],"Function '" .. funcName .. "' has not been bound." )
    self._externals[funcName] = nil
end

---Check that all EXTERNAL ink functions have a valid bound lua function.
---Note that this is automatically called on the first call to Continue().
function Story:ValidateExternalBindings()
    local missingExternals = {}
    self:ValidateExternalBindings_Container(self._mainContentContainer, missingExternals)

    self._hasValidatedExternals = true

    if #missingExternals == 0 then
        self._hasValidatedExternals = true
    else
        local fallbackMessage = ", and no fallback ink function found."
        if self.allowExternalFunctionFallbacks == false then
            fallbackMessage = " (ink fallbacks disabled)"
        end
        local message = string.format(
            "ERROR: Missing function binding for external: '%s' %s",
                table.concat(missingExternals, "', '"),
                fallbackMessage
            )
        error(message)
    end
end

---@private
--- internal function, don't call
function Story:ValidateExternalBindings_Container(c, missingExternals)
    for _,innerContent in ipairs(c.content) do
        local container = inkutils.asOrNil(innerContent, Container)
        if container == nil or container.hasValidName == false then
            self:ValidateExternalBindings_Object(innerContent, missingExternals)
        end
    end

    for k,v in ipairs(c.namedContent) do
        self:ValidateExternalBindings_Object(v, missingExternals)
    end
end

---@private
--- internal function, don't call
function Story:ValidateExternalBindings_Object(o, missingExternals)
    local container = inkutils.asOrNil(o, Container) 
    if container then
        self:ValidateExternalBindings_Container(container, missingExternals)
        return
    end

    local divert = inkutils.asOrNil(o, Divert)
    if divert and divert.isExternal then
        local name = divert:targetPathString()

        if self._externals[name] == nil then
            if self.allowExternalFunctionFallbacks then
                local fallbackFound = self:mainContentContainer().namedContent[name]
                if not fallbackFound then
                    table.insert(missingExternals, name)
                end
            else
                table.insert(missingExternals, name)
            end
        end
    end
end


--- When the named global variable changes it's value, the observer will be
---called to notify it of the change. Note that if the value changes multiple
---times within the ink, the observer will only be called once, at the end
---of the ink's evaluation. If, during the evaluation, it changes and then
---changes back again to its original value, it will still be called.
---Note that the observer will also be fired if the value of the variable
---is changed externally to the ink, by directly setting a value in
---story.variablesState.
---@param variableName string  The name of the global variable to observe.
---@param observer function A delegate function to call when the variable changes.
function Story:ObserveVariable(variableName, observer)
    self:IfAsyncWeCant("observe a new variable")
    
    if self._variableObservers == nil then
        self._variableObservers = {}
    end

    if not self.state.variablesState:GlobalVariableExistsWithName(variableName) then
        error("Cannot observe variable '"..variableName.."' because it wasn't declared in the ink story.")
    end

    if self._variableObservers[variableName] == nil then
        self._variableObservers[variableName] = DelegateUtils.createDelegate()
    end

    self._variableObservers[variableName]:add(observer)

end


---Convenience function to allow multiple variables to be observed with the same
---observer delegate function. See the singular ObserveVariable for details.
---The observer will get one call for every variable that has changed.
---@param variableNames string[] The set of variables to observe.
---@param observer function The delegate function to call when any of the named variables change.
function Story:ObserveVariables(variableNames, observer)
    for _, varName in ipairs(variableNames) do
        self:ObserveVariable(varName, observer)
    end
end

---Removes the variable observer, to stop getting variable change notifications.
---If you pass a specific variable name, it will stop observing that particular one. If you
---pass null (or leave it blank, since it's optional), then the observer will be removed
---from all variables that it's subscribed to. If you pass in a specific variable name and
---null for the the observer, all observers for that variable will be removed. 
---@param observer nil|function (Optional) The observer to stop observing.
---@param specificVariableName nil|string (Optional) Specific variable name to stop observing.
function Story:RemoveVariableObserver(observer, specificVariableName)
    self:IfAsyncWeCant ("remove a variable observer")

    if self._variableObservers == nil then
        return
    end

    if specificVariableName ~= nil then
        if self._variableObservers[specificVariableName] then
            if observer then
                self._variableObservers[specificVariableName]:sub(observer)
                if not self._variableObservers[specificVariableName]:hasAnySubscriber() then
                    self._variableObservers[specificVariableName] = nil
                end
            else
                self._variableObservers[specificVariableName] = nil
            end
        end
    else
        if observer ~= nil then
            for varName, observers in pairs(self._variableObservers) do
                observers:sub(observer)
                if not observers:hasAnySubscriber() then
                    self._variableObservers[varName] = nil
                end
            end
        end    
    end
end

---@private
function Story:VariableStateDidChangeEvent(variableName, newValueObject)
    if self._variableObservers == nil then
        return
    end

    local observers = self._variableObservers[variableName]
    if observers ~= nil then
        local val = inkutils.asOrNil(newValueObject, BaseValue)
        if val == nil then
            error("Tried to get the value of a variable that isn't a standard type")
        end 
        observers(variableName, val.value)
    end
end

function Story:TryFollowDefaultInvisibleChoice()
    local allChoices = self.state:currentChoices()
    local invisibleChoices = lume.filter(allChoices, function(c) return c.isInvisibleDefault end)
    if #invisibleChoices == 0 or #allChoices > #invisibleChoices then return false end

    local choice = invisibleChoices[1]

    self.state:callStack():setCurrentThread(choice.threadAtGeneration)

    if self._stateSnapshotAtLastNewline ~= nil then
        self.state:callStack():setCurrentThread(self.state:callStack():ForkThread())
    end


    self:ChoosePath(choice.targetPath, false)
    
    return true
end

function Story:ContinueMaximally()
    self:IfAsyncWeCant("Continue Maximally")
    local sb = {}
    while self:canContinue() do
        table.insert(sb, self:Continue())
    end
    return table.concat(sb)
end

-- SnapshotManagement

function Story:StateSnapshot()
    self._stateSnapshotAtLastNewline = self.state
    self.state = self.state:CopyAndStartPatching()
end

function Story:RestoreStateSnapshot()
    self._stateSnapshotAtLastNewline:RestoreAfterPatch()
    self.state = self._stateSnapshotAtLastNewline
    self._stateSnapshotAtLastNewline = nil

    if not self.asyncSaving then
        self.state:ApplyAnyPatch()
    end
end

function Story:DiscardSnapshot()
    if not self.asyncSaving then
        self.state:ApplyAnyPatch()
    end

    self._stateSnapshotAtLastNewline = nil
end

function Story:JTokenToRuntimeObject(...)
    return serialization.JTokenToRuntimeObject(...)
end

function Story:__tostring()
    return "Story"
end


return Story