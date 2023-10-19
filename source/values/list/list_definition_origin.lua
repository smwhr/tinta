local ListDefinitionsOrigin = classic:extend()

function ListDefinitionsOrigin:new(lists)
    self._lists = {}
    self._allUnambiguousListValueCache = {}

    for i, list in ipairs(lists) do
        self._lists[list.name] = list

        for key, val in pairs(list:items()) do
            local item = ListItem:fromSerializedKey(key)
            local listValue = ListValue(item, val)

            self._allUnambiguousListValueCache[item.itemName] = listValue
            self._allUnambiguousListValueCache[item:fullName()] = listValue
        end

    end
end

function ListDefinitionsOrigin:TryListGetDefinition(name, def)
    if name == nil then
        return {
            result = def,
            exists = false
        }
    end
    
    local definition = self._lists[name]
    if not definition then
        return {
            result = def,
            exists = false
        }
    end

    return {
        result = definition,
        exists = true
    }
end

function ListDefinitionsOrigin:FindSingleItemListWithName(name)
    local val = self._allUnambiguousListValueCache[name]
    return val
end

function ListDefinitionsOrigin:__tostring()
    return "ListDefinitionsOrigin"
end

return ListDefinitionsOrigin