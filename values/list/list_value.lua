local classic = require('libs.classic')
local inkutils = require('libs.inkutils')

local BaseValue = require('values.base')
local InkList = require('values.list.inklist')
local ListItem = require('values.list.list_item')

local IntValue = require('values.integer')
local FloatValue = require('values.float')
local StringValue = require('values.string')

---@class ListValue
local ListValue = BaseValue:extend()

function  ListValue:new(listOrSingleItem,singleValue)

    if not listOrSingleItem and not singleValue then
        self.value = InkList();
    elseif listOrSingleItem:is(InkList) then
        self.value = InkList:FromInkList(listOrSingleItem);
    elseif listOrSingleItem:is(ListItem) and type(singleValue) == "number" then
        self.value = InkList:FromSingleKeyValueItem({
            Key = listOrSingleItem,
            Value = singleValue,
        })
    end

    self.valueType = "List"
end

function ListValue:RetainListOriginsForAssignment(oldValue, newValue)
    local oldList = inkutils.asOrNil(oldValue, ListItem)
    local newList = inkutils.asOrNil(newValue, ListItem)

    if oldList and newList and newList.value:Count() == 0 then
        newList.value:SetInitialOriginNames(oldList.value:originNames())
    end
end


function ListValue:Cast(newType)

    if newType == self.valueType then
        return self
    end

    if newType == "Int" then
        local max = self.value:maxItem()
        if max.Key:isNull() then
            return IntValue(0)
        else
            return IntValue(max.Value)
        end
    end


    if newType == "Float" then
        local max = self.value:maxItem()
        if max.Key:isNull() then
            return FloatValue(0)
        else
            return FloatValue(max.Value)
        end
    end

    if newType == "String" then
        local max = self.value:maxItem()
        if max.Key:isNull() then
            return StringValue("")
        else
            return StringValue(max.Key:fullName())
        end
    end

    self:BadCast(newType)
end

return ListValue