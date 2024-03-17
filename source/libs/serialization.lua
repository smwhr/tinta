function JTokenToRuntimeObject(token)
    if 'number' == type(token) then
        return IntValue(token)
    end
        
    if 'boolean' == type(token) then
        return BooleanValue(token)
    end
    
    if 'string' == type(token) then
        if string.sub(token, 1, 1) == "^" then
            return StringValue(string.sub(token, 2))
        end
        if token == "\n" then
            return StringValue(token)
        end

        if token == "<>" then
            return Glue()
        end

        if ControlCommandName[token] then
            return ControlCommand(ControlCommandName[token])
        end

        if (token == "L^") then token = "^" end
        if NativeFunctionCall:CallExistsWithName(token) then
            return NativeFunctionCall:CallWithName(token)
        end

        if token == "->->" then
            return ControlCommand(ControlCommandType.PopTunnel)
        end
        if token == "~ret" then
            return ControlCommand(ControlCommandType.PopFunction)
        end

        if token == "void" then
            return Void()
        end

    end -- end string interpretation

    if not lume.isarray(token) then
        local obj = token

        if obj["^->"] then
            return DivertTarget(Path:FromString(obj["^->"]))
        end

        if obj["^var"] then
            local ci = tonumber(obj["ci"]) + 1
            local varPtr =  VariablePointerValue(obj["^var"], ci)
            return varPtr
        end

        local currentDivert = nil
        local proValue = nil
        if obj["->"] then
            currentDivert = Divert(false, PushPopType.Function, false)
            propValue = obj["->"]
        elseif obj["f()"] then
            currentDivert = Divert(true, PushPopType.Function, false)
            propValue = obj["f()"]
        elseif obj["->t->"] then
            currentDivert = Divert(true, PushPopType.Tunnel, false)
            propValue = obj["->t->"]
        elseif obj["x()"] then
            currentDivert = Divert(false, PushPopType.Function, true)
            propValue = obj["x()"]
        end
        if currentDivert then
            local target = propValue
            if obj["var"] then
                currentDivert.variableDivertName = target
            else
                currentDivert:setTargetPathString(target)
            end

            currentDivert.isConditional = obj["c"]
            if currentDivert.isExternal and obj["exArgs"] then
                currentDivert.externalArgs = tonumber(obj["exArgs"])
            end
            return currentDivert
        end

        if obj["*"] then
            local choice = ChoicePoint()
            choice._pathOnChoice = Path:FromString(obj["*"])

            if obj["flg"] then 
                choice:setFlags(tonumber(obj["flg"]))
            end
            return choice
        end

        if obj["VAR?"] then
            return VariableReference(obj["VAR?"]);
        elseif obj["CNT?"] then
            local readCountVarRef = VariableReference()
            readCountVarRef:setPathStringForCount(obj["CNT?"])
            return readCountVarRef
        end

        if obj["VAR="] then
            return VariableAssignment(obj["VAR="], not obj["re"], true)
        end
        if obj["temp="] then
            return VariableAssignment(obj["temp="], not obj["re"], false)
        end

        if obj["#"] then
            return Tag(obj["#"])
        end

        if obj["list"] then

            local listContent = obj["list"]
            local rawList = InkList()

            if obj["origins"] then
                local namesAsObjs = obj["origins"]
                rawList:SetInitialOriginNames(namesAsObjs)
            end

            for key,_ in pairs(listContent) do
                local nameToVal = listContent[key]
                local item = ListItem:FromString(key)
                local val = tonumber(nameToVal)
                rawList:Add(item, val)
            end

            return ListValue(rawList)
            
        end

        if obj["originalChoicePath"] ~= nil then
            return JObjectToChoice(obj)
        end

    end

    if lume.isarray(token) then
        return JArrayToContainer(token)
    end

    if token == nil then
        return nil
    end
    
    error("101. Failed to convert token to runtime object: " .. dump(token))
end

function JArrayToContainer(jArray)
    local container = Container()

    if(#jArray > 1) then
        container:AddContent(JArrayToRuntimeObjList(jArray, true))
    end

    local terminatingObj = jArray[#jArray]
    if terminatingObj ~= "TERM" then
        local namedOnlyContent = {}
        for key, value in pairs(terminatingObj) do
            if key == "#f" then
                container:setCountFlags(terminatingObj[key]) 
            elseif key == "#n" then
                container.name = tostring(terminatingObj[key])
            else
                local namedContentItem = JTokenToRuntimeObject(terminatingObj[key])
                if namedContentItem:is(Container) then
                    namedContentItem.name = key
                end
                namedOnlyContent[key] = namedContentItem
            end
        end
        container:setNamedOnlyContent(namedOnlyContent)
    end
    return container
end

function JArrayToRuntimeObjList(jArray, skipLast)
    skipLast = skipLast or false
    local ObjList = {}
    for i, jTok in pairs(jArray) do
        if not (i == #jArray and skipLast) then
            local runtimeObj = JTokenToRuntimeObject(jTok)
            if runtimeObj then
                table.insert(ObjList, runtimeObj)
            else
                error("102. Failed to convert token to runtime object" .. tostring(jTok))
            end
        end
    end
    return ObjList
end

function JTokenToListDefinitions(obj)

    local defsObj = obj
    local allDefs = {}

    for key, listDefJson in pairs(defsObj) do
        local name = tostring(key)

        local items = {}
        for nameValueKey, nameValue in pairs(listDefJson) do
            items[nameValueKey] = tonumber(nameValue)
        end
        local def = ListDefinition(name, items)
        table.insert(allDefs, def)
    end
    return ListDefinitionOrigin(allDefs)
end

function JObjectToDictionaryRuntimeObjs(jObject)
    local returnObject = {}
    for k,v in pairs(jObject) do
        returnObject[k] = JTokenToRuntimeObject(v)
    end
    return returnObject
end

function WriteDictionaryRuntimeObjs(dictionnary)
    local returnObject = {}
    for k,v in pairs(dictionnary) do
        returnObject[k] = WriteRuntimeObject(v)
    end
    return returnObject
end

function JObjectToChoice(jObj)
    local choice = Choice()
    choice.text = jObj["text"]
    choice.index = jObj["index"]
    choice.sourcePath = jObj["originalChoicePath"]
    choice.originalThreadIndex = jObj["originalThreadIndex"]
    choice:setPathStringOnChoice(jObj["targetPath"])
    return choice;
end

function WriteRuntimeContainer(container, withoutName)
    withoutName = withoutName or false
    local outputTable = {}
    for _, c in ipairs(container.content) do
        table.insert(outputTable, WriteRuntimeObject(c))
    end
    
    local namedOnlyContent = container.namedOnlyContent
    local countFlags = container.countFlags
    local hasNameProperty = container.name ~= nil and (not withoutName)
    local hasTerminator = namedOnlyContent ~= null or countFlags > 0 or hasNameProperty

    local addTo = outputTable
    if hasTerminator then
        addTo = {}
    end

    if namedOnlyContent ~= nil then
        for k, v in pairs(namedOnlyContent) do
            local name = k
            local namedContainer = inkutils.asOrNil(v, Container)
            addTo[name] = WriteRuntimeContainer(namedContainer, true)
        end
    end

    if countFlags > 0 then
        addTo["#f"] = countFlags
    end

    if hasNameProperty then
        addTo["#n"] = container.name
    end

    if hasTerminator then
        table.insert(outputTable, addTo)
    else
        table.insert(outputTable, "TERM")
    end
    return outputTable
end

function WriteListRuntimeObjs(objs)
    local outputTable = {}
    for _, obj in ipairs(objs) do
        table.insert(outputTable, WriteRuntimeObject(obj))
    end
    return outputTable
end

function WriteIntDictionary(map)
    local outputTable = {}
    for k, v in pairs(map) do
        outputTable[k] = v
    end
    return outputTable
end

function WriteInkList(listVal)
    local rawList = listVal.value
    local outputObject = {}

    local innerObject = {}
    for k, v in pairs(rawList._inner) do
        local item = ListItem:fromSerializedKey(k)
        local itemVal = v
        local itemKey = item:fullName()

        innerObject[itemKey] = itemVal
    end
    outputObject["list"] = innerObject

    if #rawList == 0 and rawList:originNames() ~= nil and #(rawList:originNames()) > 0 then
        local innerTable = {}
        for _,n in ipairs(rawList:originNames()) do
            table.insert(innerTable,n)
        end
        outputObject["origins"] = innerTable
    end
    return outputObject
end

function WriteChoice(choice)
    local outputObject = {}
    outputObject["text"] = choice.text
    outputObject["index"] = choice.index
    outputObject["originalChoicePath"] = choice.sourcePath
    outputObject["originalThreadIndex"] = choice.originalThreadIndex
    outputObject["targetPath"] = choice:pathStringOnChoice()
    return outputObject
end

function WriteRuntimeObject(obj)
    local container =  inkutils.asOrNil(obj, Container)
    if container then
        return WriteRuntimeContainer(container)
    end

    local divert = inkutils.asOrNil(obj, Divert)
    if divert then
        local divTypeKey = "->"
        if divert.isExternal then
            divTypeKey = "x()"
        elseif divert.pushesToStack then
            if divert.stackPushType == PushPopType.Function then
                divTypeKey = "f()"
            elseif divert.stackPushType == PushPopType.Tunnel then
                divTypeKey = "->t->"
            end
            
        end
        local targetStr
        if divert:hasVariableTarget() then
            targetStr = divert.variableDivertName
        else
            targetStr = divert:targetPathString()
        end
        local outputObject = {}
        outputObject[divTypeKey] = targetStr

        if divert:hasVariableTarget() then
            outputObject["var"] = true
        end

        if divert.isConditional then
            outputObject["c"] = true
        end

        if divert.externalArgs > 0 then
            outputObject["exArgs"] = divert.externalArgs
        end

        return outputObject
    end

    local choicePoint = inkutils.asOrNil(obj, ChoicePoint)
    if choicePoint then
        return {
            ["*"]= choicePoint:pathStringOnChoice(),
            ["flg"] = choicePoint:flags()
        }
    end

    local boolVal = inkutils.asOrNil(obj, BooleanValue)
    if boolVal then
        return boolVal.value
    end
    local intVal = inkutils.asOrNil(obj, IntValue)
    if intVal then
        return intVal.value
    end
    local floatVal = inkutils.asOrNil(obj, FloatValue)
    if floatVal then
        return floatVal.value
    end

    local strVal = inkutils.asOrNil(obj, StringValue)
    if strVal then
        if strVal.isNewline then
            return "\n"
        else
            return "^"..strVal.value
        end
    end
    
    local listVal = inkutils.asOrNil(obj, ListValue)
    if listVal then
        return WriteInkList(listVal)
    end
    
    local divTargetVal = inkutils.asOrNil(obj, DivertTarget)
    if divTargetVal then
        return {
            ["^->"] = divTargetVal.value:componentsString()
        }
    end

    local varPtrVal = inkutils.asOrNil(obj, VariablePointerValue)
    if varPtrVal then
        return {
            ["^var"] = varPtrVal.value,
            ["ci"] = varPtrVal.contextIndex
        }
    end

    local glue = inkutils.asOrNil(obj, Glue)
    if glue then
        return "<>"
    end

    local controlCmd = inkutils.asOrNil(obj, ControlCommand)
    if controlCmd then
        return ControlCommandValues[controlCmd.value]
    end

    local nativeFunc = inkutils.asOrNil(obj, NativeFunctionCall)
    if nativeFunc then
        local name = nativeFunc.name

        if name == "^" then
            name = "L^"
        end
        return name
    end

    local varRef = inkutils.asOrNil(VariableReference)
    if varRef then
        local readCountPath = varRef:pathStringForCount()
        if readCountPath ~= nil then
            return {["CNT?"] = readCountPath}
        else
            return {["VAR?"] = varRef.name}
        end
    end

    local varAss = inkutils.asOrNil(VariableAssignment)
    if varAss then
        local outputObject = {}
        if varAss.isGlobal then
            outputObject["VAR="] = varAss.variableName
        else
            outputObject["temp="] = varAss.variableName
        end

        if varAss.isNewDeclaration == false then
            outputObject["re"] = true
        end
        return outputObject
    end

    local voidObj = inkutils.asOrNil(obj, Void)
    if voidObj then
        return "void"
    end

    local tag = inkutils.asOrNil(obj, Tag)
    if tag then
        return { ["#"] = tag.text }
    end

    local choice = inkutils.asOrNil(obj, Choice)
    if choice then
        return WriteChoice(choice)
    end

    error("Failed to convert runtime object to token " .. tostring(obj))
end


return {
    ["JTokenToListDefinitions"] = JTokenToListDefinitions,
    ["JTokenToRuntimeObject"] = JTokenToRuntimeObject,
    ["JArrayToRuntimeObjList"] = JArrayToRuntimeObjList,
    ["JObjectToDictionaryRuntimeObjs"] = JObjectToDictionaryRuntimeObjs,
    ["WriteListRuntimeObjs"] = WriteListRuntimeObjs,
    ["WriteRuntimeObject"] = WriteRuntimeObject,
    ["WriteIntDictionary"] = WriteIntDictionary,
    ["WriteDictionaryRuntimeObjs"] = WriteDictionaryRuntimeObjs,
    ["WriteChoice"] = WriteChoice
 }