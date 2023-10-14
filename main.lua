local lume = require('libs.lume')
local classic = require('libs.classic')
local dump = require('libs.dump')


-- local book = require("tests/hello_world")
-- local book = require("tests/whitespace")
-- local book = require("tests/weave_gathers")
local book = require("tests/multi_thread")
-- local book = require("tests/thread_in_logic")

function dbg(t)
    print(dump(t))
end

Story = require('engine.story')
story = Story(book)
-- print(dump(story:mainContentContainer()))
-- os.exit()
function next()
    local t = story:Continue()
    print("Text is ", dump(t))
end

local choices = {}

repeat
    while story:canContinue() do
        local t = story:Continue()
        print(t)
    end
    choices = story:currentChoices()
    for i,c in ipairs(story:currentChoices()) do
        print(i, c.text)
    end
    if #choices > 0 then
        print("----")
        io.write("?> ")
        choiceIndex = io.read()
        print(choiceIndex)
        story:ChooseChoiceIndex(choiceIndex)
    end
until #choices == 0
print("DONE")