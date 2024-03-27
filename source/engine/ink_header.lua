classic = import('../libs/classic')
---@type Lume
lume = import('../libs/lume')
inkutils = import('../libs/inkutils')
PRNG = import('../libs/prng')
serialization = import('../libs/serialization')
---@type DelegateUtils
DelegateUtils = import('../libs/delegate')

BaseValue = import('../values/base')

ListItem = import('../values/list/list_item')
ListValue = import('../values/list/list_value')
ListDefinition = import('../values/list/list_definition')
ListDefinitionOrigin = import('../values/list/list_definition_origin')
InkList = import('../values/list/inklist')

CreateValue = import('../values/create')
BooleanValue = import('../values/boolean')
ChoicePoint = import('../values/choice_point')
Choice = import('../values/choice')
Container = import('../values/container')
ControlCommandType = import('../constants/control_commands/types')
ControlCommandName = import('../constants/control_commands/names')
ControlCommandValues = import('../constants/control_commands/values')
ControlCommand = import('../values/control_command')
DivertTarget = import('../values/divert_target')
Divert = import('../values/divert')
FloatValue = import('../values/float')
Glue = import('../values/glue')
IntValue = import('../values/integer')
NativeFunctionCallName = import('../constants/native_functions/names')
NativeFunctionCall = import('../values/native_function')
Path = import('../values/path')
Pointer = import('../engine/pointer')
StringValue = import('../values/string')
SearchResult = import('../values/search_result')
---@type Tag
Tag = import('../values/tag')
VariableAssignment = import('../values/variable_assignment')
VariablePointerValue = import('../values/variable_pointer')
VariableReference = import('../values/variable_reference')
Void = import('../values/void')

---@type VariableState
VariablesState = import('../engine/variables_state')
---@type CallStackElement
CallStackElement = import('../engine/call_stack/element')
---@type CallStackThread
CallStackThread = import('../engine/call_stack/thread')
---@type CallStack
CallStack = import('../engine/call_stack')

PushPopType = import('../constants/push_pop_type')
---@type Flow
Flow = import("../engine/flow")
---@type StatePatch
StatePatch = import('../engine/state_patch')
---@type StoryState
StoryState = import('../engine/story_state')