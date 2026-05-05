---@class DataModule
---@field save_mode fun(mode: PlayMode): nil
---@field load_mode fun(): PlayMode
local M = {}

-- note: MODULES

local state_file = vim.fn.stdpath("data") .. "/yt-playlist/state.json"

function M.save_mode(mode)
	-- create directory if not exists
	vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")

	local file = io.open(state_file, "w")

	if not file then
		vim.notify("Failed to save state", vim.log.levels.ERROR)
		return
	end

	file:write(vim.json.encode({ mode = mode }))
	file:close()
end

function M.load_mode()
	local file = io.open(state_file, "r")

	if not file then
		return "normal"
	end

	local content = file:read("*a")
	file:close()

	local ok, state = pcall(vim.json.decode, content)

	if not ok or not state then
		vim.schedule(function()
			vim.notify("Failed to load state", vim.log.levels.ERROR)
		end)
		return "normal"
	end

	return state.mode
end

return M
