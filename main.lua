local lume = require('libs.lume')
local classic = require('libs.classic')
local dump = require('libs.dump')

-- local book = require("thread")
local book = require("hello")
-- local book = require("white")

function dbg(t)
    print(dump(t))
end

Story = require('engine.story')
story = Story(book)
-- print(dump(story.mainContentContainer))


while story:canContinue() do
    local t = story:Continue()
        print("Text is ", dump(t))
end
print("----")
for i,c in ipairs(story:currentChoices()) do
    print(i, c.text)
end