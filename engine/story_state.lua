local classic = require('libs.classic')
local lume = require('libs.lume')

local PushPopType = require('constants.push_pop_type')

local CallStack = require('engine.call_stack')
local VariableState = require('engine.variable_state')
local Pointer = require('engine.pointer')
local StringValue = require('values.string')
local Glue = require('values.glue')
local CommandControl = require('values.control_command')
local ListValue = require('values.list.list')

local CommandControlType = require('constants.control_commands.types')

---@class StoryState
local StoryState = classic:extend()

function StoryState:new(story)
    self.storySeed = math.random(100000)
    self.previousRandom = 0

    self.story = story
    self.callStack = CallStack(story)
    self.variablesState = VariableState(self.callStack)
    self.evaluationStack = {}
    self.visitCounts = {}
    self.turnIndices = {}
    self.currentTurnIndex = -1 -- actual -1
    
    self.didSafeExit = false
    self.outputStream = {}
    self.outputStreamTextDirty = true
    self.outputStreamTagsDirty = true
    
    self._currentChoices = {}

    self.currentErrors = {}
    self.currentWarnings = {}

    self._currentText = nil

    self.divertedPointer = Pointer:Null()

    self:GoToStart()
end

function StoryState:GoToStart()
    self.callStack:currentElement().currentPointer = Pointer:StartOf(
            self.story.mainContentContainer
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
                elseif outputObj.commandType == ControlCommandType.EndTag then
                    inTag = false
                end
            end
        end
        self._currentText = table.concat(sb)
        self.outputStreamTextDirty = false
    end
    return self._currentText
end

function StoryState:currentPointer()
    return self.callStack:currentElement().currentPointer
end

function StoryState:setCurrentPointer(pointer)
    self.callStack:currentElement().currentPointer = pointer:Copy()
end

function StoryState:previousPointer()
    return self.callStack.currentThread.previousPointer
end

function StoryState:setPreviousPointer(pointer)
    self.callStack.currentThread.previousPointer = pointer:Copy()
end

function StoryState:ResetOutput() --add parameter when needed
    self.outputStream = {}
    self:OutputStreamDirty()
end

function StoryState:OutputStreamDirty()
    self.outputStreamTextDirty = true
    self.outputStreamTagsDirty = true
end

function StoryState:PushToOutputStream(obj)
    if obj and obj:is(StringValue) then
        local listText = TrySplittingHeadTailWhitespace(obj)
        for i, textObj in ipairs(listText) do
            self:PushToOutputStreamIndividual(textObj)
        end
        self:OutputStreamDirty()
        return
    end
    self:PushToOutputStreamIndividual(obj)
    self:OutputStreamDirty()
end 

function StoryState:PopFromOutputStream(count)
    self.outputStream = lume.slice(self.outputStream, 1, #self.outputStream - count)
    self:OutputStreamDirty()
end

function StoryState:PushToOutputStreamIndividual(obj)
    local includeInOutput = true
    if obj == nil then
        --Do nothing
    elseif obj:is(Glue) then
        self:TrimNewlinesFromOutputStream()
        includeInOutput = true
    elseif obj:is(StringValue) then
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
            if o:is(CommandControl) and o.value == ControlCommandType.BeginString  then
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

        if trimIndex ~= 0  then
            if obj.isNewLine then
                includeInOutput = false
            elseif obj:isNonWhitespace() then
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
        elseif obj.isNewLine then
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
                if obj.isNewLine then return true
                elseif obj.isNonWhitespace then break end
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
    for i = #self.outputStream, 1, -1 do
        local obj = self.outputStream[i]
        if obj:is(CommandControl) then
            break
        end
        if obj:is(StringValue) and ob:isNonWhitespace() then
            break
        end
        table.remove(self.outputStream, i)
    end
    self:OutputStreamDirty()
end

function StoryState:TrimWhitespaceFromFunctionEnd()
    local functionStartPoint = self.callStack:currentElement().functionStartInOutputStream
    if functionStartPoint == 0 then
        functionStartPoint = 1
    end
    for i = #self.outputStream, functionStartPoint, -1 do
        local obj = self.outputStream[i]
        if not obj:is(StringValue) then
            if obj:is(CommandControl) then break end
            if obj.isNewLine or obj.isInlineWhiteSpace then
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
    local newPointer = self.story.PointerAtPath(path)
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
        elseif obj:is(CommandControl) then
            break
        end
    end
    self:OutputStreamDirty()
end


function StoryState:canContinue()
    print(dump(self:currentPointer()))
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
    local containerPathStr = Path:of(container):componentString()
    local count2 = self.visitCounts[containerPathStr]
    if count2 ~= nil then
        return count2
    else
        return 0
    end
end
function StoryState:IncrementVisitCountForContainer()
    local containerPathStr = Path:of(container):componentString()
    local count = self.visitCounts[containerPathStr]
    if count ~= nil then
        self.visitCounts[containerPathStr] = count + 1
    else
        self.visitCounts[containerPathStr] = 1
    end
end
function StoryState:RecordTurnIndexVisitToContainer()
    local containerPathStr = Path:of(container):componentString()
    self.turnIndices[containerPathStr] = self.currentTurnIndex
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
        table.insert(popped, table.remove(self.evaluationStack))
    end
    return popped
end

function StoryState:PushEvaluationStack(obj)
    if obj:is(ListValue) then
        -- @TODO: Implement
        error("List not implemented yet")
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


function TrySplittingHeadTailWhitespace(stringValue)
    local text = stringValue.value
    local lines = lume.split(text, "\n")
    local sb = {}
    for i, line in ipairs(lines) do
        local trimmed = lume.trim(line)

        if i == 1 and (lume.charAt(line,1) == " " or lume.charAt(line,1) == "\t") then
            table.insert(sb, StringValue(" "))
        end
        
        if trimmed ~= "" then
            table.insert(sb, StringValue(trimmed))
        end

        table.insert(sb, StringValue("\n"))
        
        if i == #lines and (lume.charAt(line, #line) == " " or lume.charAt(line, #line) == "\t") then
            table.insert(sb, StringValue(" "))
        end
        
    end
    return sb
end

return StoryState
