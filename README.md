# Tinta

This is a lua port of inkle's [ink](https://github.com/inkle/ink), a scripting language for writing interactive narrative.

tinta is fully compatible with the original version, has zero dependency and is known to work with love2d and the playdate sdk.

## Installation

Clone this repository and add the `tinta/source` directory to your project as `tinta`.

## Writing and compiling Ink

You will need to use a third party compiler (the original inklecate or the inkjs compiler) to compile your ink files to json. 

## Running your ink

For performance reasons, tinta is not able to run the compiled json files directly. Instead, you will need to convert the json to lua using the provided `json_to_lua` command line tool.

```sh
json_to_lua.sh my_story.json > my_story.lua
```

Once converted, you can `import` your story and run it.

```lua
local storyDefinition = import("my_story")

Story = import('tinta/engine/story')
story = Story(storyDefinition)
```

2 examples loop to run the story are provided in the `run.lua` file

A simple synchronous version:
```lua
    --- SIMPLE SYNC VERSION
    while story:canContinue() do
        local t = story:Continue()
        io.write(t)
        local tags = story:currentTags()
        if  #tags > 0 then
            io.write(" # tags: " .. table.concat(tags, ", "), '\n')
        end
    end
```

A more complex asynchronous version for limited environments (like on the playdate):

```lua
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
```

## CLI Player

A fancy one-liner to run your story from the command line. From the `source` folder of the repository, run:

```sh
TMPSUFFIX=.lua; lua run.lua =(../json_to_lua.sh /path/to/your/game/my_story.ink.json >(cat ))
```

Useful commands when prompted for input are:

- `save` to save the current state of the story
- `load` to load the last saved state


## Toybox

tinta is also available using the [toybox](https://pypi.org/project/toyboxpy/) package manager. 

```sh
pip install toyboxpy
toybox add smwhr/tinta
```

then in your lua code:

```lua
import "../toyboxes/toyboxes"

local storyDefinition = import("my_story")
local story = Story(book)
```

## Missing features

- Flows
- Saving and loading (working on it !)
- External functions
- Reading/Setting variables

Feel free to contribute to the project if you need any of these features.  
The lua code is a straight port of the original ink code, so it should be easy to port missing features.