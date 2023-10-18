local lume = require('libs.lume')
local classic = require('libs.classic')
local dump = require('libs.dump')


-- local book = require("tests/hello_world")
-- local book = require("tests/whitespace")
-- local book = require("tests/weave_gathers")
-- local book = require("tests/multi_thread")
-- local book = require("tests/thread_in_logic")
-- local book = require("tests/conditional_choices")
-- local book = require("tests/list_range")
-- local book = require("tests/logic_in_choices")

function load_book(bookname)
    if bookname:sub(#bookname-3,#bookname) == ".lua" then
        bookname = bookname:sub(1,#bookname-4)
    end
    return require(bookname)
end

function dbg(t)
    print(dump(t))
end

print("Loading book", arg[1])
local book = load_book(arg[1])

Story = require('engine.story')
story = Story(book)
-- print("LISTDEF ", dump(story.listDefinitions))
-- print(dump(story:mainContentContainer()))
function next()
    local t = story:Continue()
    print("Text is ", dump(t))
end

local choices = {}

repeat
    while story:canContinue() do
        local t = story:Continue()
        io.write(t)
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
print("\nDONE.")