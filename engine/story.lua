local lume = require('libs.lume')
local classic = require('libs.classic')
local PRNG = require('libs.prng')
local dump = require('libs.dump')

local StringValue = require('values.string')
local IntValue = require('values.integer')
local FloatValue = require('values.float')
local BooleanValue = require('values.boolean')
local Glue = require('values.glue')
local Void = require('values.void')

local ControlCommand = require('values.control_command')
local ControlCommandType = require('constants.control_commands.types')
local ControlCommandName = require('constants.control_commands.names')


local NativeFunctionCall = require('values.native_function')
local NativeFunctionCallName = require('constants.native_functions.names')

local DivertTarget = require('values.divert_target')
local VariablePointerValue = require('values.variable_pointer')
local VariableAssignment = require('values.variable_assignment')
local Path = require('values.path')
local Divert = require('values.divert')
local PushPopType = require('constants.push_pop_type')
local ChoicePoint = require('values.choice_point')
local Choice = require('values.choice')
local Container = require('values.container')

local StoryState = require('engine.story_state')
local Pointer = require('engine.pointer')


---@class Story
local Story = classic:extend()


function Story:new(book)
  
    self.mainContentContainer = JTokenToRuntimeObject(book.root)
    print("Successfull conversion")
    self.state = StoryState(self)
    print("Successfull state initialization")

    self.prevContainers = {}
end

function Story:canContinue()
    return self.state:canContinue()
end

function Story:currentText()
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

function Story:Continue()
    self:ContinueInternal()
    return self:currentText();
end

function Story:ContinueInternal()
    if not self:canContinue() then
        error("Can't continue - should check canContinue() before calling Continue")
    end
    self.state.didSafeExit = false;
    self.state:ResetOutput();

    local outputStreamEndsInNewline = false
    repeat
        outputStreamEndsInNewline = self:ContinueSingleStep();
        if outputStreamEndsInNewline then break end
    until self:canContinue()

    if outputStreamEndsInNewline or not self:canContinue() then
        self.state._previousText = nil
    end
end

function Story:ContinueSingleStep()
    self:Step()

    if not self:canContinue() and not self.state.callStack:elementIsEvaluateFromGame() then
        self:TryFollowDefaultInvisibleChoice()
    end

    if not self.state:inStringEvaluation() then
        if self.state:currentText() == "" then return true end
        if self.state._previousText ~= nil then
            local change = self:CalculateNewlineOutputStateChange(
                self.state._previousText,
                self.state:currentText()
            )
            if change == "ExtendedBeyondNewline" then
                self.state._previousText = nil
                return true
            elseif change == "NewlineRemoved" then
                self.state._previousText = nil
            end
            print("Previous", self.state._previousText)
            print("Current", self.state:currentText())
            print(change)
            return true
        end
        
        if self.state:outputStreamEndsInNewline() then
            if self:canContinue() then
                self.state._previousText = self.state:currentText()
            else
                self.state._previousText = nil
            end
        end
    end
    return false
end

function Story:CalculateNewlineOutputStateChange(prevText, currText)
    local newLineStillExists = (
            #currText >= #prevText
        and #prevText > 0
        and currText:sub(#currText, #currText) == "\n"
    )

    print(
        currText,
        #currText >= #prevText,
        #prevText > 0,
        "|"..currText:sub(#currText, #currText) .. "|"
    )

    if #prevText == #currText and newLineStillExists then return "NoChange" end
    if not newLineStillExists then return "NewLineRemoved" end

    for i=#prevText, #currText do
        local c = currText:sub(i,i)
        if c == " " or c == "\t" then return "ExtendedBeyondNewLine" end
    end
    return "NoChange"
end

function Story:Step()
    print("==============Step=================")
    local shouldAddToStream = true
    local pointer = self.state:currentPointer():Copy()

    if pointer:isNull() then
        return
    end

    -- Container
    containerToEnter = pointer:Resolve()

    while containerToEnter and containerToEnter:is(Container) do
        self:VisitContainer(containerToEnter, true)
        if #containerToEnter.content == 0 then break end

        pointer = Pointer:StartOf(containerToEnter):Copy()
        containerToEnter = pointer:Resolve()
    end

    self.state:setCurrentPointer(pointer:Copy())

    local currentContentObj = pointer:Resolve()
    local isLogicOrFlowControl = self:PerformLogicAndFlowControl(currentContentObj)

    if self.state:currentPointer():isNull() then
        return
    end

    if currentContentObj and currentContentObj:is(ChoicePoint) then
        local choicePoint = currentContentObj
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
        if currentContentObj and currentContentObj:is(VariablePointerValue) then
            local varPointer = currentContentObj
            if varPointer.contextIndex == 0 then
                local contextIdx = self.state.callStack:ContextForVariableNamed(varPointer.variableName)
                currentContentObj = VariablePointerValue(
                    varPointer.variableName,
                    contextIdx
                )
            end
        end
        if self.state:inExpressionEvaluation() then
            self.state:PushToOutputStream(currentContentObj)
        else
            self.state:PushToOutputStream(currentContentObj)
        end
    end

    self:NextContent()

    if currentContentObj and currentContentObj:is(ControlCommand) then
        local controlCmd = currentContentObj
        if controlCmd.value == ControlCommandType.StartThread then
            self.state.callStack:PushThread()
        end
    end

end

function Story:NextContent()
    self.state:setPreviousPointer(self.state:currentPointer():Copy())
    if not self.state.divertedPointer:isNull() then
        self.state:setCurrentPointer(self.state.divertedPointer:Copy())
        self.state.divertedPointer = Pointer:Null()

        self:VisitChangedContainersDueToDivert()
        if not self.state:currentPointer():isNull() then return end
    end

    local successfulPointerIncrement = self:IncrementContentPointer()
    if not successfulPointerIncrement then
        local didPop = false

        if self.state.callStack:CanPop(PushPopType.Function) then
            self.state:PopCallStack(PushPopType.Function)
            if self.state:inExpressionEvaluation() then
                self.state:PushEvaluationStack(Void())
            end
            didPop = true
        elseif self.state.callStack:canPopThread() then
            self.state.callStack:PopThread()
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
        local prevAncestor = nil
        if resolvedPreviousAncestor:is(Container) then
            prevAncestor = resolvedPreviousAncestor
        elseif previousPointer.container:is(Container) then
            prevAncestor = previousPointer.container
        end
        while prevAncestor do
            table.insert(self.prevContainers, prevAncestor)
            if prevAncestor.parent == nil then break end
            if prevAncestor.parent:is(Container) then
                prevAncestor = prevAncestor.parent
            else
                break
            end
        end
    end

    local currentChildOfContainer = pointer:Resolve()
    
    if currentChildOfContainer == nil then return end

    local currentContainerAncestor = currentChildOfContainer.parent
    local allChildrenEnteredAtStart = true

    while (
        currentContainerAncestor:is(Container)
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

        currentChildOfContainer = currentContainerAncestor
        currentContainerAncestor = currentContainerAncestor.parent
    end

end

function Story:IncrementContentPointer()
    local successfulIncrement = true
    local pointer = self.state.callStack:currentElement().currentPointer:Copy()
    pointer.index = pointer.index + 1

    while pointer.index > #pointer.container.content do
        successfulIncrement = false
        if pointer.container.parent == nil then break end
        if not pointer.container.parent:is(Container) then break end
        local nextAncestor = pointer.container.parent
        local indexInAncestor = lume.find(nextAncestor.content, pointer.container)
        if indexInAncestor == nil then break end

        pointer = Pointer(nextAncestor, indexInAncestor)
        pointer.index = pointer.index + 1

        successfulIncrement = true
    end
    
    if not successfulIncrement then pointer = Pointer:Null() end
    
    self.state.callStack:currentElement().currentPointer = pointer:Copy()
    
    return successfulIncrement
end

function Story:VisitContainer(container, atStart)
    if (not container.countingAtStartOnly) or atStart then
        if container.visitsShouldBeCounted then
            self.state:IncrementVisitCountForContainer(container)
        end
        if container.turnIndexShouldBeCounted then
            self.state:RecordTurnIndexVisitToContainer()
        end
    end
end

function Story:ResetState()
    self.state = StoryState(self)
    self:ResetGlobals()
end

function Story:ResetGlobals()
    self.state.variablesState = VariableState(self.state.callStack)
    self.state.variablesState:SnapshotDefaultGlobals();
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

        if currentDivert.hasVariableTarget then
            local varName = currentDivert.variableDivertName
            local varContents = self.state.variablesState:GetVariableWithName(varName)
            if not varContents then
                error("Tried to divert using a target from a variable that could not be found (" .. varName .. ")")
            end

            if not varContents:is(DivertTarget) then
                error("Tried to divert to a target from a variable, but the variable (" .. varName .. ") didn't contain a divert target")
            end

            self.state.divertedPointer = self:PointerAtPath(varContents.targetPath)
        else
            self.state.divertedPointer = currentDivert:targetPointer():Copy()
        end

        if currentDivert.pushesToStack then
            self.state.callStack:Push(
                currentDivert.stackPushType,
                nil,
                #self.state.outputStream
            )
        end

        if self.state.divertedPointer:isNull() and not currentDivert.isExternal then
           error("Divert resolution failed", dump(currentDivert)) 
        end
        
        return true

    -- Command Control
    elseif contentObj:is(CommandControl) then
        local evalCommand = contentObj;
        if     evalCommand == ControlCommandType.EvalStart then
            self.state.setInExpressionEvaluation(true)

        elseif evalCommand == ControlCommandType.EvalEnd then
            self.state.setInExpressionEvaluation(false)

        elseif evalCommand == ControlCommandType.EvalOutput then
            if #self.state.evaluationStack > 0 then
                local output = self.state:PopEvaluationStack()
                if not output:is(Void) then
                    local text = StringValue(tostring(output))
                    self.state:PushToOutputStream(text)
                end
            end
        elseif evalCommand == ControlCommandType.NoOp then
            -- Do nothing
        elseif evalCommand == ControlCommandType.Duplicate then
            self.state:PushEvaluationStack(self.state:PeekEvaluationStack())

        elseif evalCommand == ControlCommandType.PopEvaluatedValue then
            self.state:PopEvaluationStack()

        elseif evalCommand == ControlCommandType.PopFunction
        or     evalCommand == ControlCommandType.PopTunnel then
            local popType = nil
            if evalCommand.value == ControlCommandType.PopFunction then
                popType = PushPopType.Function
            else
                popType = PushPopType.Tunnel
            end

            local overrideTunnelReturnTarget = nil
            if popType == PushPopType.Tunnel then
                local popped = self.state:PopEvaluationStack()
                overrideTunnelReturnTarget = popped
                if(not overrideTunnelReturnTarget:is(DivertTarget)) then
                    if not popped:is(Void) then
                        error("Expected void if ->-> doesn't override target")
                    end
                end
            end

            if self.state:TryExitFunctionEvaluationFromGame() then
                -- Do nothing
            elseif self.state.callStack:currentElement().type ~= popType or self.state.callStack:canPop() then
                error("Mismatched push/pop in flow")
            else
                self.state:PopCallStack()
            end

        elseif evalCommand == ControlCommandType.BeginString then
            self.state:PushToOutputStream(evalCommand)
            self.state.inExpressionEvaluation = false

        elseif evalCommand == ControlCommandType.BeginTag then
            self.state:PushToOutputStream(evalCommand)

        elseif evalCommand == ControlCommandType.EndTag then
            if self.state.inStringEvaluation() then
                local contentStackForTag = {}
                local outPutCountConsumed = 0
                for i = #self.state.outputStream, 1, -1 do
                    local obj = self.state.outputStream[i]
                    outPutCountConsumed = outPutCountConsumed + 1
                    
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
            else
                self.state:PushToOutputStream(evalCommand)
            end

        elseif evalCommand == ControlCommandType.EndString then
            local contentStackForString = {}
            local contentToRetain = {}
            
            local outPutCountConsumed = 0
            for i = #self.state.outputStream, 1, -1 do
                local obj = self.state.outputStream[i]
                outPutCountConsumed = outPutCountConsumed + 1
                
                if obj:is(ControlCommand) and obj.value == ControlCommandType.BeginString then
                    -- Do nothing
                end
                if obj:is(Tag) then
                    table.insert(contentToRetain, obj)
                end
                if obj:is(StringValue) then
                    table.insert(contentStackForString, obj)
                end
            end

            self.state:PopFromOutputStream(outPutCountConsumed)

            for _, rescuedTag in ipairs(contentToRetain) do
                self.state:PushToOutputStream(rescuedTag)
            end

            contentStackForString = lume.reverse(contentStackForString)

            local sb = {}
            for _, s in ipairs(contentStackForString) do
                table.insert(sb, tostring(s.value))
            end
            self.state.inExpressionEvaluation = true
            self.state:PushEvaluationStack(StringValue(table.concat(sb)))

        elseif evalCommand == ControlCommandType.ChoiceCount then
            local choiceCount = #self.state:generatedChoices()
            self.state:PushEvaluationStack(IntValue(choiceCount))

        elseif evalCommand == ControlCommandType.Turns then
            self.state:PushEvaluationStack(IntValue(self.state.currentTurnIndex))

        elseif evalCommand == ControlCommandType.TurnsSince
        or     evalCommand == ControlCommandType.ReadCount then
        elseif evalCommand == ControlCommandType.Random then
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
            

        elseif evalCommand == ControlCommandType.SeedRandom then
            local seed = self.state:PopEvaluationStack()
            if not seed:is(IntValue) then
                error("Invalid value passed to SEED_RANDOM")
            end
            math.randomseed(seed.value)
            self.state.storySeed = seed.value
            self.state:PushEvaluationStack(Void())

        elseif evalCommand == ControlCommandType.VisitIndex then
            local count = self.state:VisitCountForContainer(self.state:currentPointer().container)
            self.state:PushEvaluationStack(IntValue(count))

        elseif evalCommand == ControlCommandType.SequenceShuffleIndex then
            local shuffleIndex = self:NextSequenceShuffleIndex()
            self.state:PushEvaluationStack(IntValue(shuffleIndex))

        elseif evalCommand == ControlCommandType.StartThread then
            -- Done in main step function
        elseif evalCommand == ControlCommandType.Done then
            if self.state.callStack:canPopThread()then
                self.callStack:PopThread()
            else
                self.state.didSafeExit = true
                self.state:setCurrentPointer(Pointer:Null())
            end

        elseif evalCommand == ControlCommandType.End then
            self.state:ForceEnd()

        elseif evalCommand == ControlCommandType.ListFromInt then
            --@TODO: Implement
            error("ListFromInt not implemented yet")
        elseif evalCommand == ControlCommandType.ListRange then
            --@TODO: Implement
            error("ListRange not implemented yet")
        elseif evalCommand == ControlCommandType.ListRandom then
            --@TODO: Implement
            error("ListRandom not implemented yet")
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

        if varRef:pathForCount() ~= nil then
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
        result = this.mainContentContainer:ContentAtPath(
            path, nil, pathLengthToUse
        )
        p.container = result.container
    else
        result = this.mainContentContainer.ContentAtPath(path);
        p.container = result.container;
    end

    return p
end

function Story:NextSequenceShuffleIndex()
    local numElementsIntVal = self.state:PopEvaluationStack()
    if not numElementsIntVal:is(IntValue) then
        error("expected number of elements in sequence for shuffle index")
    end

    local seqContainer = self.state:currentPointer().container
    local numElements = numElementsIntVal.value
    local seqCountVal = self.state:PopEvaluationStack() --IntValue
    local seqCount = seqCountVal.value

    local loopIndex = seqCount / numElements
    local iterationIndex = seqCount % numElements
    local seqPathStr = Path:of(seqContainer):componentString()
    local sequenceHash = lume.reduce(lume.explode(seqPathStr), function(acc, comp) return acc+string.byte(comp) end, 0)
    local randomSeed = sequenceHash + loopIndex + self.state.storySeed
    local random = PRNG(randomSeed)

    local unpickedIndices = {}
    for i = 1, numElements do
        table.insert(i)
    end

    for i = 1, iterationIndex do
        local chosen = random:range(1, #unpickedIndices)
        local chosenIndex = unpickedIndices[chosen]
        table.remove(unpickedIndices, chosen)
        if i == iterationIndex then
            return chosenIndex
        end
    end

    error("Should never reach here")

end

function Story:PopChoiceStringAndTags(tags)
    local choiceOnlyStrVal = self.state:PopEvaluationStack()
    while (
             #(self.evaluationStack) > 0 
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
    local choiceTextOnly = ""
    local tags = {}

    if choicePoint.hasChoiceOnlyContent then
        choiceTextOnly = self:PopChoiceStringAndTags(tags) or ""
    end
    if choicePoint.hasStartContent then
        startText = self.PopChoiceStringAndTags(tags) or ""
    end

    if choicePoint.onceOnly then
        local visitCount = self.state:VisitCountForContainer(choice)
        if visitCount > 0 then
            showChoice = false
        end
    end

    if not showChoice then return ni end

    local choice = Choice()
    choice.targetPath = choicePoint.pathOnChoice
    choice.sourcePath = Path:of(choicePoint):componentString()
    choice.isInvisibleDefault = choicePoint.isInvisibleDefault;
    choice.threadAtGeneration = self.state.callStack.ForkThread();
    choice.tags = lume.reverse(tags)
    choice.text = lume.trim(startText .. choiceOnlyText)

    return choice
end

function Story:ChoosePath(p, incrementingTurnIndex)
    incrementingTurnIndex = incrementingTurnIndex or true
    self.state:SetChosenPath(p, incrementingTurnIndex)
    self:VisitChangedContainersDueToDivert()
end

function Story:TryFollowDefaultInvisibleChoice()
    local allChoices = self.state._currentChoices
    local invisibleChoices = lume.filter(allChoices, function(c) return c.isInvisibleDefault end)
    if #invisibleChoices == 0 or #allChoices > #invisibleChoices then return false end

    local choice = invisibleChoices[1]

    self.state.callStack:setCurrentThread(self.state.callStack:ForkThread())

    self:ChoosePath(choice.target, false)
    
    return true
end



function JTokenToRuntimeObject(token)
    if 'number' == type(token) then
        return IntValue(token)
    end
        
    if 'boolean' == type(token) then
        return BooleanValue(token)
    end
    
    if 'string' == type(token) then
        if string.sub(token, 1, 1) == "^" then
            return StringValue(string.sub(token, 2))
        end
        if token == "\n" then
            return StringValue(token)
        end

        if token == "<>" then
            return Glue()
        end

        if ControlCommandName[token] then
            return ControlCommand(ControlCommandName[token])
        end

        if (token == "L^") then token = "^" end
        if NativeFunctionCallName[token] then
            return NativeFunctionCall(NativeFunctionCallName[token])
        end

        if token == "->->" then
            return ControlCommand(ControlCommandType.PopTunnel)
        end
        if token == "~ret" then
            return ControlCommand(ControlCommandType.PopFunction)
        end

        if token == "void" then
            return Void()
        end

    end -- end string interpretation

    if not lume.isarray(token) then
        local obj = token

        if obj["^->"] then
            return DivertTarget(Path:FromString(obj["^->"]))
        end

        if obj["^var"] then
            local ci = tonumber(obj["ci"])
            return VariablePointerValue(obj["^var"], ci)
        end

        local currentDivert = nil
        local proValue = nil
        if obj["->"] then
            currentDivert = Divert()
            propValue = obj["->"]
        elseif obj["f()"] then
            currentDivert = Divert(true)
            propValue = obj["f()"]
        elseif obj["->t->"] then
            currentDivert = Divert(true, PushPopType.Tunnel)
            propValue = obj["->t->"]
        elseif obj["x()"] then
            currentDivert = Divert(false, PushPopType.Function, true)
            propValue = obj["x()"]
        end
        if currentDivert then
            local target = propValue
            if obj["var"] == propValue then
                currentDivert.variableDivertName = target
            else
                currentDivert:setTargetPathString(target)
            end

            currentDivert.isConditional = obj["c"]
            if currentDivert.isExternal and obj["exArgs"] then
                currentDivert.externalArgs = tonumber(obj["exArgs"])
            end
            return currentDivert
        end

        if obj["*"] then
            local choice = ChoicePoint()
            choice.pathStringOnChoice = obj["*"]

            if obj["flg"] then 
                choice.flags = tonumber(obj["flg"])
            end

            return choice
        end

        if obj["VAR?"] then
            error("Variable reference not implemented yet")
        end
        if obj["VAR="] then
            return VariableAssignment(obj["VAR="], not obj["re"], true)
        end
        if obj["temp="] then
            return VariableAssignment(obj["VAR="], not obj["re"], false)
        end

        if obj["#"] then
            error("Tag not implemented yet")
        end

        if obj["list"] then
            error("List not implemented yet")
        end

    end

    if lume.isarray(token) then
        return JArrayToContainer(token)
    end

    if token == nil then
        return nil
    end
    
    error("101. Failed to convert token to runtime object: ",  dump(token))
end

function JArrayToContainer(jArray)
    local container = Container()

    container:AddContent(JArrayToRuntimeObjList(jArray, true))

    local terminatingObj = jArray[#jArray]
    if not terminatingObj == "TERM" then
        local namedOnlyContent = {}
        for key, value in pairs(terminatingObj) do
            if key == "#f" then
                container.setCountFlags(terminatingObj[key]) 
            elseif key == "#n" then
                container.name = tostring(terminatingObj[key])
            else
                local namedContentItem = JTokenToRuntimeObject(terminatingObj[key])
                if namedContentItem.is(Container) then
                    namedContentItem.name = key
                end
                namedOnlyContent[key] = namedContentItem
            end
        end
    end
    return container
end

function JArrayToRuntimeObjList(jArray, skipLast)
    skipLast = skipLast or false
    local ObjList = {}
    for i, jTok in ipairs(jArray) do
        if not (i == #jArray and skipLast) then
            local runtimeObj = JTokenToRuntimeObject(jTok)
            if runtimeObj then
                table.insert(ObjList, runtimeObj)
            else
                error("102. Failed to convert token to runtime object", dump(jTok))
            end
        end
    end
    return ObjList
end

function Story:JTokenToRuntimeObject(...)
    return JTokenToRuntimeObject(...)
end

function Story:__tostring()
    return "Story"
end


return Story