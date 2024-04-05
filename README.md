# Tinta

This is a lua port of inkle's [ink](https://github.com/inkle/ink), a scripting language for writing interactive narrative.

tinta is fully compatible with the language (see missing features below for what's missing in the engine), has zero dependency and is known to work with love2d and the playdate sdk.

## Installation

Clone this repository and add the `tinta/source` directory to your project as `tinta`.

## Writing and compiling Ink

tinta only implements a _runtime_ for ink, you will need to use a third party compiler (the original inklecate or the inkjs compiler) to compile your ink files to json. 

## Running your ink

For performance reasons, tinta is not able to run the compiled json files directly. Instead, you will need to convert the json to lua using the provided `json_to_lua.sh` or `json_to_lua.ps1` command line tool.

```sh
json_to_lua.sh my_story.json my_story.lua
```

Note that you might need to change the script execution policy if you want to run the ps1 script.

```
json_to_lua.ps1 my_story.json my_story.lua
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
### Saving and Loading

Saving would return a lua table representing the current state of the story.

```lua
local saveData = story.state:save()

-- if on playdate
playdate.datastore.write(saveData)
```

Loading overwrites the current state of the story with the saved data

```lua
--if on playdate
local saveData = playdate.datastore.read()

story.state:load(saveData)
```

### Variable Observers

Variable Observers are functions that get called whenever a variable declared in ink is changed.

You can add a variable observer like this:

```lua
-- Anonymous function (if you don't remove them later)
story:ObserveVariable("myVarDeclaredInInk", function(varName, val) 
        -- do stuff
		print(varName.." changed to ".. tostring(val))
end)


-- Named function
local function MyVarObserver(varName, val)
    -- do stuff
    print(varName.." changed to ".. tostring(val))
end
story:ObserveVariable("myVarDeclaredInInk", MyVarObserver)
```

Note that variable observers are identified by function addresses, adding the same observer multiple times is the same as adding it only once.

Additionally, you could add the same observer to multiple variables:

```lua
-- Anonymous function (if you don't remove them later)
story:ObserveVariables({ "myVarDeclaredInInk1", "myVarDeclaredInInk2" }, function(varName, val) 
        -- do stuff
		print(varName.." changed to ".. tostring(val))
end)
```

Removing variable observers:

```lua
-- Remove all observers on myVarDeclaredInInk
story:RemoveVariableObserver(nil, "myVarDeclaredInInk")

-- Remove a specific observer on all variables
story:RemoveVariableObserver(MyVarObserver, nil)

-- Remove a specific observer on myVarDeclaredInInk
story:RemoveVariableObserver(MyVarObserver, "myVarDeclaredInInk")
```

### External Functions

External Functions are lua functions that can be called from ink. 

Binding External Functions:

```lua
local MyFunc(args)
    -- do stuff
end
story:BindExternalFunction("functionNameDeclaredInInk", MyFunc, true)
```

Fallbacks are enabled by default. Which means if an external function is called but none has been bound, we call the fallback function defined in ink.

The first `Continue()` call will validate all external function bindings. If you forgot to bind an external function while the function has no fallback (or fallback is disabled), it throws an error. 

**You can't bind multiple functions to the same external function declaration.** If you try to do so, it throws an error.

You could remove bindings, but in that case you should have a fallback defined in ink or bind with another lua function immediately afterwards. Otherwise calling that function would result in error.

**Note that external function only receives a table as its first argument.** If you declare your function in ink like this:

```ink
EXTERNAL someFunction(argumentA, argumentB)
```

Your lua function should be:

```lua
function someFunction(args)
    local argumentA = args[1]
    local argumentB = args[2]
    -- do something with argumentA and argumentB
end
```

```lua
story:UnbindExternalFunction("functionNameDeclaredInInk")
```

Unbinding a function that hasn't been bound throws an error. 

You could check if a function has been bound by using the following:

```lua
-- returns nil if the function hasn't been bound. 
local externalFunc = story:TryGetExternalFunction("functionNameDeclaredInInk")
```

### Flows

Flows exist even if you don't use them. Every story has a default flow named `DEFAULT_FLOW`. 

Some nottable getters:

```lua
story:currentFlowName()

-- true if current flow is "DEFAULT_FLOW"
story:currentFlowIsDefaultFlow()

story:aliveFlowNames()
```

To create or switch to a named flow:

```lua
story:SwitchFlow("MyFlow")
-- Convenient function to switch to default flow
story:SwitchToDefaultFlow()
```

This will create a new flow if that flow is not found. When this happens, the newly created flow doesn't know where it should be, and calling `Continue` would not advance the story, thus you must use `story:ChoosePathString(...)` to specify where that flow should start.

Note that, though temporary variables and callstacks are flow-specific, global variables are shared between flows.

You could remove a flow:

```lua
story:RemoveFlow("MyFlow")
```

You can't remove the default flow.



## CLI Player

A fancy one-liner to run your story from the command line. From the `source` folder of the repository, run:

```sh
TMPSUFFIX=.lua; lua run.lua =(../json_to_lua.sh /path/to/your/game/my_story.ink.json >(cat ))
```

Useful commands when prompted for input are:

- `save` to save the current state of the story
- `load` to load the last saved state
- `-> your_knot` to jump to a specific knot
- `quit` or `q` to quit the story


## Toybox

tinta is also available using the [toybox](https://pypi.org/project/toyboxpy/) package manager. 

```sh
pip install toyboxpy
toybox add smwhr/tinta
```

then in your lua code:

```lua
import "../toyboxes/toyboxes"

local my_story = import("my_story")
local story = Story(my_story)
```

## Löve2D

Download the full source code and copy the `source` folder inside your Löve2D game directory.  
Rename this folder `tinta`.

then in your lua code:

```
Story = require("tinta/love")

local my_story = import("my_story")
local story = Story(my_story)
```

## Notably missing features

- Global event broadcasts (e.g. whenever story continues)

Feel free to contribute to the project if you need any of these features.  
The lua code is a straight port of the original ink code, so it should be easy to port missing features.
