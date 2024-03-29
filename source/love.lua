package.path = 'tinta/?.lua;' .. package.path
love.filesystem.setRequirePath('tinta/?.lua;'.. love.filesystem.getRequirePath( ))

if not import then import = require end
compat = import("compat.lua51")
Story = import("engine.story")

return Story