--#################### ############ ####################
--#################### Async Region ####################
--#################### ############ ####################

---@generic T
---@alias AsyncThunk fun(callback?: fun(value: T))

---@class AsyncModule
---@field sync fun<T>(func: fun(...): T|nil): AsyncThunk<T>
---@field wait fun<T>(defer: AsyncThunk<T>): T
---@field wait_all fun(defer: AsyncThunk[]): any
---@field wrap fun(fun: function): function

local co = coroutine
local unpack = table.unpack or unpack

---@generic T
---@param func fun(...): T
---@param callback? fun(value: T)
local pong = function(func, callback)
	assert(type(func) == "function", "type error :: expected func")
	local thread = co.create(func)
	local step = nil
	step = function(...)
		local pack = { co.resume(thread, ...) }
		local status = pack[1]
		local ret = pack[2]
		assert(status, ret)
		if co.status(thread) == "dead" then
			if callback then
				(function(_, ...)
					callback(...)
				end)(unpack(pack))
			end
		else
			assert(type(ret) == "function", "type error :: expected func - coroutine yielded some value")
			ret(step)
		end
	end
	step()
end

-- use with pong, creates thunk factory
local wrap = function(func)
	assert(type(func) == "function", "type error :: expected func")
	local factory = function(...)
		local params = { ... }
		local thunk = function(step)
			table.insert(params, step)
			return func(unpack(params))
		end
		return thunk
	end
	return factory
end

-- many thunks -> single thunk
local join = function(thunks)
	local len = #thunks
	local done = 0
	local acc = {}

	local thunk = function(step)
		if len == 0 then
			return step()
		end
		for i, tk in ipairs(thunks) do
			assert(type(tk) == "function", "thunk must be function")
			local callback = function(...)
				acc[i] = { ... }
				done = done + 1
				if done == len then
					step(unpack(acc))
				end
			end
			tk(callback)
		end
	end
	return thunk
end

---@generic T
---@param defer AsyncThunk
---@return T
local await = function(defer)
	assert(type(defer) == "function", "type error :: expected func")
	return co.yield(defer)
end

---@param defer AsyncThunk[]
local await_all = function(defer)
	assert(type(defer) == "table", "type error :: expected table")
	return co.yield(join(defer))
end

return {
	sync = wrap(pong),
	wait = await,
	wait_all = await_all,
	wrap = wrap,
}
