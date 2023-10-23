local SearchResult = classic:extend()

function SearchResult:new()
    self.obj = nil
    self.approximate = false
end

function SearchResult:correctObj()
    if self.approximate then
        return nil
    end
    return self.obj
end

function SearchResult:container()
    if self.obj:is(Container) then
        return self.obj
    end
    return nil
end

function SearchResult:__tostring()
    return "SearchResult"
end

return SearchResult