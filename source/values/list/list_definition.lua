local ListDefinition = classic:extend()

function ListDefinition:new(name, items)
    self.name = name
    self._items = nil
    self._itemNameToValues = items or {}

end

function ListDefinition:items()
    if self._items == nil then
        self._items = {}
        for key, value  in pairs(self._itemNameToValues) do
        local item = ListItem(self.name, key)
        self._items[item:serialized()] = value
        end
    end
    return self._items
end

function ListDefinition:TryGetItemWithValue(val, item)
    for key,value in pairs(self._itemNameToValues) do
        if value == val then
            item = ListItem(self.name, key)
            return {
                result = item,
                exists = true
            }
        end
    end
    item = ListItem:Null()
    return {
        result = item,
        exists = false
    }
end


function ListDefinition:__tostring()
    return "ListDefinition"
end

return ListDefinition