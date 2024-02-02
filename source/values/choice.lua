local Choice = classic:extend()

function Choice:new()
    self.text = ""
    self.index = 1
    self.threadAtGeneration = nil
    self.sourcePath = ""
    self.targetPath = nil
    self.isInvisibleDefault = false
    self.tags = {}
    self.originalThreadIndex = 1
end

function Choice:pathStringOnChoice()
    return self.targetPath:componentsString()
end

return Choice