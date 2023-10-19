if not import then import = require end
package.path = '/?.lua;' .. package.path

local lume = import('libs.lume')
local classic = import('libs.classic')
dump = import('libs.dump')


-- local book = import("tests/hello_world")
-- local book = import("tests/whitespace")
-- local book = import("tests/weave_gathers")
-- local book = import("tests/multi_thread")
-- local book = import("tests/thread_in_logic")
-- local book = import("tests/conditional_choices")
-- local book = import("tests/list_range")
-- local book = import("tests/logic_in_choices")

function load_book(bookname)
    if bookname:sub(#bookname-3,#bookname) == ".lua" then
        bookname = bookname:sub(1,#bookname-4)
    end
    return import(bookname)
end

function dbg(t)
    print(dump(t))
end

-- print("Loading book", arg[1])
local book = load_book(arg[1])

Story = import('engine.story')
story = Story(book)

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