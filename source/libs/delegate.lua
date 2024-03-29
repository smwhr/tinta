---@class DelegateUtils
local DelegateUtils = {}

---@class Delegate
---@field func table
---@field hasAnySubscriber function
---@field add function
---@field sub function 

---@return Delegate d
function DelegateUtils.createDelegate()
	local T = {
		func = {},
		add = function(self, func)
			if self and func then
				self.func[#self.func + 1] = func
			else
				error("Self, Function expected, got " .. type(self) .. ", " .. type(func), 2)
			end
		end,
		sub = function(self, func)
			if self and func then
				for i = 1, #self.func do
					local v = self.func[i]
					if v == func then
						table.remove(self.func, i)
					end
				end
			else
				error("Self, Function expected, got " .. type(self) .. ", " .. type(func), 2)
			end
		end,
		hasAnySubscriber = function(self) return self.func ~= nil and #self.func > 0 end
	}
	local M = {
		__call = function(tbl, ...)
			if type(tbl.func) == "table" then
				local c, r = 0, {}
				for k, v in pairs(tbl.func) do
					if type(v) == "function" then
						c = c + 1
						r[c] = { pcall(v, ...) }
					end
				end
				return c, r
			end
		end,
		__add = function(self, func)
			self:add(func)
		end,
		__sub = function(self, func)
			self:sub(func)
		end,
	}
	return setmetatable(T, M)
end

---@class Event

---@param del Delegate
---@return Event e
function DelegateUtils.createEvent(del)
	return {
		add = function(func)
			del.func[#del.func + 1] = func
		end,
		sub = function(func)
			local limit = #del.func
			for i = 1, limit do
				if del.func[i] == func then
					table.remove(del.func, i)
				end
			end
		end,
	}
end


return DelegateUtils