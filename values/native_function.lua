local classic = require('libs.classic')
local inkutils = require('libs.inkutils')
local CreateValue = require('values.create')
local FName = require('constants.native_functions.names')

local BaseValue = require('values.base')
local Void = require('values.void')
local IntValue = require('values.integer')
local BooleanValue = require('values.boolean')
local ListValue = require('values.list.list_value')
local ListItem = require('values.list.list_item')

---@class NativeFunctionCall
local NativeFunctionCall = classic:extend()

local _nativeFunctions = {}

function NativeFunctionCall:new(name, numberOfParameters)
    self._prototype = nil
    self._isPrototype  = false
    self._operationFuncs = nil
    self._numberOfParameters = 0

    if name == nil and numberOfParameters == nil then
        GenerateNativeFunctionsIfNecessary()
    elseif numberOfParameters == nil then
        GenerateNativeFunctionsIfNecessary()
        self:setName(name)
    else --bot not nil
        self._isPrototype = true
        self:setName(name)
        self._numberOfParameters = numberOfParameters
    end
end

function NativeFunctionCall:setName(name)
    self.name = name
    if not self._isPrototype then
        if _nativeFunctions == nil then
            error("_nativeFunctions not generated")
        else
            self._prototype = _nativeFunctions[self.name]
        end
        
    end

end

function NativeFunctionCall:numberOfParameters()
    if self._prototype then
        return self._prototype:numberOfParameters()
    else
        return self._numberOfParameters
    end
end

function NativeFunctionCall:CallExistsWithName(name)
    GenerateNativeFunctionsIfNecessary()
    return _nativeFunctions[name]
end

function NativeFunctionCall:CallWithName(name)
    return NativeFunctionCall(name)
end

function NativeFunctionCall:Call(parameters)
    if self._prototype then
        return self._prototype:Call(parameters)
    end

    if self:numberOfParameters() ~= #parameters then
        error("Unexpected number of parameters")
    end

    local hasList = false
    for _, p in pairs(parameters) do
        if p:is(Void) then
            error('Attempting to perform operation on a void value. Did you forget to "return" a value from a function you called here?')
        end
        if p:is(ListValue) then
            hasList = true
        end
    end

    if #parameters == 2 and hasList then
        return self:CallBinaryListOperation(parameters)
    end

    local coercedParams = self:CoerceValuesToSingleType(parameters)
    local coercedType = coercedParams[1].valueType

    if (coercedType == "Int") then
        return self:CallType(coercedParams)
    elseif (coercedType == "Float") then
        return self:CallType(coercedParams)
    elseif (coercedType == "String") then
        return self:CallType(coercedParams)
    elseif (coercedType == "DivertTarget") then
        return self:CallType(coercedParams)
    elseif (coercedType == "List") then
        return self:CallType(coercedParams)
    end

    return nil
end

function valTypeValue(valType)
    return ({
        Bool = -1,
        Int = 0,
        Float = 1,
        List = 2,
        String = 3,
        DivertTarget = 4,
        VariablePointer = 5,
      })[valType]
end


function NativeFunctionCall:CoerceValuesToSingleType(parametersIn)
    local valType = "Int"
    local specialCaseList = nil

    for _,val in ipairs(parametersIn) do
        if valTypeValue(val.valueType) > valTypeValue(valType) then
            valType = val.valueType
        end
        if val.valueType == "List" then
            specialCaseList = inkutils.asOrNil(val, ListValue)
        end
    end
    local parametersOut = {}

    if valType == "List" then
        for _, val in pairs(parametersIn) do
            if val.valueType == "List" then
                table.insert(parametersOut, val)
            elseif val.valueType == "Int" then
                local intVal = tonumber(val.value)
                local list = specialCaseList.value:originOfMaxItem()
                local item = list:TryGetItemWithValue(intVal, ListItem:Null())
                if item.exists then
                    local castedValue = ListValue(item.result, intVal)
                    table.insert(parametersOut, castedValue)
                else
                    error("Could not find List item with the value " .. intVal .. " in " .. list.name)
                end
            else
                error("Cannot mix Lists and " .. valueType .. " values in this operation")
            end
        end
    else
        for _, val in pairs(parametersIn) do
            local castedValue = val:Cast(valType)
            table.insert(parametersOut, castedValue)
        end
    end

    return parametersOut
end

function NativeFunctionCall:CallType(parametersOfSingleType)
    local param1 = parametersOfSingleType[1]
    local valType = param1.valueType
    local val1 = param1

    local paramCount = #parametersOfSingleType

    if paramCount == 2 or paramCount == 1 then
        local opForTypeObj = self._operationFuncs[valType]
        if not opForTypeObj then
           error( "Cannot perform operation " .. self.name .. " on " .. valType) 
        end
        if paramCount == 2 then
            local param2 = parametersOfSingleType[2] or error("Expected a second argument")
            local val2 = param2

            local resultVal = opForTypeObj(val1.value, val2.value)
            return CreateValue(resultVal)
        else
            local resultVal = opForTypeObj(val1.value)
            if self.name == FName.Int then
                return CreateValue(resultVal, "Int")
            elseif self.name == FName.Float then
                return CreateValue(resultVal, "Float")
            else
                return CreateValue(resultVal, param1.valueType)
            end
        end
    else
        error("Unexpected number of parameters to NativeFunctionCall: " .. tostring(paramCount))
    end
end

function NativeFunctionCall:CallBinaryListOperation(parameters)
    if     (self.name == "+" or self.name == "-")
       and parameters[1]:is(ListValue)
       and parameters[2]:is(IntValue) 
    then
        return self:CallListIncrementOperation(parameters)
    end

    local v1 = parameters[1]
    local v2 = parameters[2]

    if      (self.name == "&&" or self.name == "||")
        and (v1.valueType ~= "List" or v2.valueType ~= "List")
    then
        local op = self._operationFuncs["Int"]
        local bv1 = v1:isTruthy() and 1 or 0
        local bv2 = v2:isTruthy() and 1 or 0
        local result op(bv1, bv2)
        return BooleanValue(result)
    end

    if v1.valueType == "List" and v2.valueType == "List" then
        return self:CallType({v1,v2})
    end

    error("Can not call use " .. self.name .. " operation on " .. v1.valueType .. " and " .. v2.valueType )
end

function NativeFunctionCall:AddOpFuncForType(valType, op)
    if self._operationFuncs == nil then
        self._operationFuncs = {}
    end
    self._operationFuncs[valType] = op
end

function NativeFunctionCall:__tostring()
    return "NativeFunctionCall " .. self.name
end

function GenerateNativeFunctionsIfNecessary()
    if #_nativeFunctions == 0 then
        -- Int operations
        AddIntBinaryOp(FName.Add, function(x, y) return  x + y end)
        AddIntBinaryOp(FName.Subtract, function(x, y) return  x - y end)
        AddIntBinaryOp(FName.Multiply, function(x, y) return  x * y end)
        AddIntBinaryOp(FName.Divide, function(x, y) return  math.floor(x / y) end)
        AddIntBinaryOp(FName.Mod, function(x, y) return  x % y end)
        AddIntUnaryOp(FName.Negate, function(x) return  -x end)

        AddIntBinaryOp(FName.Equal, function(x, y) return x == y end)
        AddIntBinaryOp(FName.Greater, function(x, y) return x > y end)
        AddIntBinaryOp(FName.Less, function(x, y) return x < y end)
        AddIntBinaryOp(FName.GreaterThanOrEquals, function(x, y) return x >= y end)
        AddIntBinaryOp(FName.LessThanOrEquals, function(x, y) return x <= y end)
        AddIntBinaryOp(FName.NotEquals, function(x, y) return x ~= y end)
        AddIntUnaryOp(FName.Not, function(x) return x == 0 end)

        AddIntBinaryOp(FName.And, function(x, y) return x ~= 0 and y ~= 0 end)
        AddIntBinaryOp(FName.Or, function(x, y) return x ~= 0 or y ~= 0 end)

        AddIntBinaryOp(FName.Max, function(x, y) return math.max(x, y) end)
        AddIntBinaryOp(FName.Min, function(x, y) return math.min(x, y) end)

        AddIntBinaryOp(FName.Pow, function(x, y) return math.pow(x, y) end)
        AddIntUnaryOp(FName.Floor, Identity)
        AddIntUnaryOp(FName.Ceiling, Identity)
        AddIntUnaryOp(FName.Int, Identity)
        AddIntUnaryOp(FName.Float, function(x) return x end)

        -- Float operations

        AddFloatBinaryOp(FName.Add, function(x, y) return  x + y end)
        AddFloatBinaryOp(FName.Subtract, function(x, y) return  x - y end)
        AddFloatBinaryOp(FName.Multiply, function(x, y) return  x * y end)
        AddFloatBinaryOp(FName.Divide, function(x, y) return  x / y end)
        AddFloatBinaryOp(FName.Mod, function(x, y) return  x % y end)
        AddFloatUnaryOp(FName.Negate, function(x) return  -x end)

        AddFloatBinaryOp(FName.Equal, function(x, y) return x == y end)
        AddFloatBinaryOp(FName.Greater, function(x, y) return x > y end)
        AddFloatBinaryOp(FName.Less, function(x, y) return x < y end)
        AddFloatBinaryOp(FName.GreaterThanOrEquals, function(x, y) return x >= y end)
        AddFloatBinaryOp(FName.LessThanOrEquals, function(x, y) return x <= y end)
        AddFloatBinaryOp(FName.NotEquals, function(x, y) return x ~= y end)
        AddFloatUnaryOp(FName.Not, function(x) return x == 0 end)

        AddFloatBinaryOp(FName.And, function(x, y) return x ~= 0 and y ~= 0 end)
        AddFloatBinaryOp(FName.Or, function(x, y) return x ~= 0 or y ~= 0 end)

        AddFloatBinaryOp(FName.Max, function(x, y) return math.max(x, y) end)
        AddFloatBinaryOp(FName.Min, function(x, y) return math.min(x, y) end)

        AddFloatBinaryOp(FName.Pow, function(x, y) return math.pow(x, y) end)
        AddFloatUnaryOp(FName.Floor, function(x) return math.floor(x) end)
        AddFloatUnaryOp(FName.Ceiling, function(x) return math.ceil(x) end);
        AddFloatUnaryOp(FName.Int, function(x) return math.floor(x) end)
        AddFloatUnaryOp(FName.Float, Identity)


        -- String operations
        AddStringBinaryOp(FName.Add, function(x, y) return x .. y end)
        AddStringBinaryOp(FName.Equal, function(x, y) return x == y end)
        AddStringBinaryOp(FName.NotEquals, function(x, y) return not (x == y) end)
        AddStringBinaryOp(FName.Has, function(x, y) return string.find(x, y) end)
        AddStringBinaryOp(FName.Hasnt, function(x, y) return not string.find(x, y) end)


        -- List operations

        AddListBinaryOp(FName.Add, function(x, y) return x:Union(y) end)
        AddListBinaryOp(FName.Subtract, function(x, y) return x:Without(y) end)
        AddListBinaryOp(FName.Has, function(x, y) return x:Contains(y) end)
        AddListBinaryOp(FName.Hasnt, function(x, y) return not x:Contains(y) end)
        AddListBinaryOp(FName.Intersect, function(x, y) return x:Intersect(y) end)


        AddListBinaryOp(FName.Equal, function(x, y) return x:Equals(y) end)
        AddListBinaryOp(FName.Greater, function(x, y) return x:GreaterThan(y) end)
        AddListBinaryOp(FName.Less, function(x, y) return x:LessThan(y) end)
        AddListBinaryOp(FName.GreaterThanOrEquals, function(x, y)
            return x:GreaterThanOrEquals(y)
        end)
        AddListBinaryOp(FName.LessThanOrEquals, function(x, y)
            return x:LessThanOrEquals(y)
        end)
        AddListBinaryOp(FName.NotEquals, function(x, y) return not x:Equals(y) end)

        AddListBinaryOp(FName.And, function(x, y) return x:Count() > 0 and y:Count() > 0 end)
        AddListBinaryOp(FName.Or, function(x, y) return x:Count() > 0 or y:Count() > 0 end)
    
        AddListUnaryOp(FName.Not, function(x) 
            if x:Count() == 0 then 
                return 1 
            else 
                    return 0 
            end 
        end)

        AddListUnaryOp(FName.Invert, function(x) return x:inverse() end)
        AddListUnaryOp(FName.All, function(x) return x:all() end)
        AddListUnaryOp(FName.ListMin, function(x) return x:MinAsList() end)
        AddListUnaryOp(FName.ListMax, function(x) return x:MaxAsList() end)
        AddListUnaryOp(FName.Count, function(x) return x:Count() end)
        AddListUnaryOp(FName.ValueOfList, function(x) return x:maxItem().Value end)


        local divertTargetsEqual = function(d1, d2) return d1:Equals(d2) end
        local divertTargetsNotEqual = function(d1, d2) return not d1:Equals(d2) end

        AddOpToNativeFunc( FName.Equal,2, "DivertTarget", divertTargetsEqual)
        AddOpToNativeFunc( FName.NotEquals,2,"DivertTarget", divertTargetsNotEqual)
    end
end

function Identity(x)
    return x
end

function AddOpToNativeFunc(name, args, valType, op)
    local nativeFunc = _nativeFunctions[name]
    if nativeFunc == nil then
        nativeFunc = NativeFunctionCall(name, args)
        _nativeFunctions[name] = nativeFunc
    end
    nativeFunc:AddOpFuncForType(valType, op)
end

function AddIntBinaryOp(name, op)
    AddOpToNativeFunc(name, 2, "Int", op)
end
function AddIntUnaryOp(name, op)
    AddOpToNativeFunc(name, 1, "Int", op)
end
function AddFloatBinaryOp(name, op)
    AddOpToNativeFunc(name, 2, "Float", op)
end
function AddFloatUnaryOp(name, op)
    AddOpToNativeFunc(name, 1, "Float", op)
end
function AddStringBinaryOp(name, op)
    AddOpToNativeFunc(name, 2, "String", op)
end
function AddListBinaryOp(name, op)
    AddOpToNativeFunc(name, 2, "List", op)
end
function AddListUnaryOp(name, op)
    AddOpToNativeFunc(name, 1, "List", op)
end

return NativeFunctionCall