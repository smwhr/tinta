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

return CallStackElement