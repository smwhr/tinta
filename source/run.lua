if not import then import = require end
package.path = '/?.lua;' .. package.path

dump = import('libs/dump')

if _VERSION == "Lua 5.1" then
    compat = import("compat/lua51")
else
    compat = import("compat/lua54")
end

function load_storyDefinition(storyDefinitionName)
    if storyDefinitionName:sub(#storyDefinitionName-3,#storyDefinitionName) == ".lua" then
        storyDefinitionName = storyDefinitionName:sub(1,#storyDefinitionName-4)
    end
    return import(storyDefinitionName)
end

-- local storyDefinition = import("tests/hello_world")
-- local storyDefinition = import("tests/whitespace")
-- local storyDefinition = import("tests/weave_gathers")
-- local storyDefinition = import("tests/multi_thread")
-- local storyDefinition = import("tests/thread_in_logic")
-- local storyDefinition = import("tests/conditional_choices")
-- local storyDefinition = import("tests/list_range")
-- local storyDefinition = import("tests/logic_in_choices")
local storyDefinition = load_storyDefinition(arg[1])

local save = {}

Story = import('engine/story')
story = Story(storyDefinition)

local choices = {}

repeat

    --- ASYNC VERSION
    local textBuffer = {}
    repeat
        if not story:canContinue() then
            break
        end
        story:ContinueAsync(300)
        if story:asyncContinueComplete() then
            local currentText = story:currentText()
            local currentTags = story:currentTags()
            table.insert(textBuffer,{
                text = currentText,
                tags = currentTags
            })
        end
    until not story:canContinue()

    for _, item in pairs(textBuffer) do
        io.write(item.text)
        if #item.tags > 0 then
            io.write(" # tags: " .. table.concat(item.tags, ", "), '\n')
        end
    end
    

    --- SIMPLE SYNC VERSION
    -- while story:canContinue() do
    --     local t = story:Continue()
    --     io.write(t)
    --     local tags = story:currentTags()
    --     if  #tags > 0 then
    --         io.write(" # tags: " .. table.concat(tags, ", "), '\n')
    --     end
    -- end


    io.write("\n")
    choices = story:currentChoices()
    for i,c in ipairs(story:currentChoices()) do
        io.write(i .. ": ", c.text)
        if #c.tags > 0 then
            io.write(" # tags: " .. table.concat(c.tags, ", "))
        end
        io.write("\n")
    end
    if #choices > 0 then
        io.write("?> ")
        userInput = io.read()
        if userInput == "quit" 
        or userInput == "q"  
        or userInput == nil -- ctrl+D
        then
            print("Quitting...")
            break
        elseif userInput:sub(1,2) == "->" then
            local path = lume.trim(userInput:sub(3))
            story:ChoosePathString(path)
        elseif userInput == "save" then
            save = story.state:save()
        elseif userInput == "load" then
            story.state:load(save)
        elseif userInput:match("^%-?%d+$") ~= nil then
            story:ChooseChoiceIndex(userInput)
        else
            print("Should be a choice number, save or load")
        end
    end
until #choices == 0
print("DONE.\n")