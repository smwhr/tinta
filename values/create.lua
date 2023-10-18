local inkutils = require('libs.inkutils')

local IntValue = require('values.integer')
local FloatValue = require('values.float')
local BooleanValue = require('values.boolean')
local StringValue = require('values.string')
local DivertTargetValue = require('values.divert_target')
local ListValue = require('values.list.list_value')

local Path = require('values.path')
local InkList = require('values.list.inklist')

function CreateValue(val, preferredNumberType)        
    
    if preferredNumberType then
        if preferredNumberType == "Int" and inkutils.isInteger(val) then
            return IntValue(tonumber(val))
        elseif preferredNumberType == "Float" and type(val) == "number" then
            return FloatValue(tonumber(val))
        end
    end

    if type(val) == "boolean" then
        return BooleanValue(val)
    end

    if type(val) == "string" then
        return StringValue(val)
    elseif inkutils.isInteger(val) then
        return IntValue(val)
    elseif type(val) == "number" then
        return FloatValue(val)
    elseif val:is(Path) then
        return DivertTargetValue(val)
    elseif val:is(InkList) then
        return ListValue(val)
    end
end

return CreateValue