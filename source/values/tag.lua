---@class Tag
local Tag = classic:extend()

function Tag:new(tagText)
    self.text = tagText or ""
end

return Tag