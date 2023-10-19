if not import then import = require end
package.path = '/?.lua;' .. package.path

dump = import('libs/dump')


-- local storyDefinition = import("tests/hello_world")
-- local storyDefinition = import("tests/whitespace")
-- local storyDefinition = import("tests/weave_gathers")
-- local storyDefinition = import("tests/multi_thread")
-- local storyDefinition = import("tests/thread_in_logic")
-- local storyDefinition = import("tests/conditional_choices")
-- local storyDefinition = import("tests/list_range")
-- local storyDefinition = import("tests/logic_in_choices")

function load_storyDefinition(storyDefinitionName)
    if storyDefinitionName:sub(#storyDefinitionName-3,#storyDefinitionName) == ".lua" then
        storyDefinitionName = storyDefinitionName:sub(1,#storyDefinitionName-4)
    end
    return import(storyDefinitionName)
end

local storyDefinition = load_storyDefinition(arg[1])

Story = import('engine/story')
story = Story(storyDefinition)

local choices = {}

repeat
    while story:canContinue() do
        local t = story:Continue()
        io.write(t)
    end
    io.write("\n")
    choices = story:currentChoices()
    for i,c in ipairs(story:currentChoices()) do
        io.write(i .. ": ", c.text,"\n")
    end
    if #choices > 0 then
        io.write("?> ")
        choiceIndex = io.read()
        story:ChooseChoiceIndex(choiceIndex)
    end
until #choices == 0
print("DONE.\n")