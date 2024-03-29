---@class StatePatch
local StatePatch = classic:extend()

function StatePatch:new(toCopy)
    if toCopy ~= nil then
        self._globals = lume.clone(toCopy._globals)
        self._changedVariables = lume.unique(toCopy._changedVariables)
        self._visitCounts = lume.clone(toCopy._visitCounts)
        self._turnIndices = lume.clone(toCopy._turnIndices)
    else
        self._globals = {}
        self._changedVariables = {}
        self._visitCounts = {}
        self._turnIndices = {}
    end
end

function StatePatch:TryGetGlobal(name, value)
    if name ~= nil and self._globals[name] ~= nil then
        return { result = self._globals[name], exists = true }
    end
    return { result = value, exists = false }
end

function StatePatch:SetGlobal(name, value)
    self._globals[name] = value
end

function StatePatch:AddChangedVariable(name)
    table.insert(self._changedVariables, name)
    self._changedVariables = lume.unique(self._changedVariables)
end

function StatePatch:TryGetVisitCount(container, count)
    if self._visitCounts[container] ~= nil then
        return { result = self._visitCounts[container], exists = true }
    end
    return { result = count, exists = false }
end

function StatePatch:SetVisitCount(container, count)
    self._visitCounts[container] = count
end

function StatePatch:TryGetTurnIndex(container, index)
    if self._turnIndices[container] ~= nil then
        return { result = self._turnIndices[container], exists = true }
    end
    return { result = index, exists = false }
end

function StatePatch:SetTurnIndex(container, index)
    self._turnIndices[container] = index
end

return StatePatch