---@class DataModule
---@field save_state fun(state: StateData): nil
---@field load_state fun(): StateData|nil
---@field add_playlist fun(): nil
local M = {}

-- note: MODULES

---@type AsyncModule
local async = require("yt-playlist.async")

local state_file = vim.fn.stdpath("data") .. "/yt-playlist/state.json"

function M.save_state(state)
	vim.schedule(function()
		-- create directory if not exists
		vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")

		local previous_state = M.load_state()
		local current_state = {}

		if not previous_state then
			current_state = vim.tbl_extend("force", { mode = "normal", playlists = "", current_playlist = {} }, state)
		else
			current_state = vim.tbl_extend("force", previous_state, state)
		end

		local file = io.open(state_file, "w")

		if not file then
			vim.notify("Failed to save state", vim.log.levels.ERROR)
			return
		end

		file:write(vim.json.encode(current_state))
		file:close()
	end)
end

function M.load_state()
	local file = io.open(state_file, "r")

	if not file then
		return {}
	end

	local content = file:read("*a")
	file:close()

	if vim.trim(content) == "" then
		M.save_state({})
	end

	local ok, state = pcall(vim.json.decode, content)

	if not ok or not state then
		vim.schedule(function()
			-- vim.notify("Failed to load state", vim.log.levels.ERROR) -- todo: may remove
		end)

		return nil
	end

	return state
end

-- todo: here
function M.add_playlist()
	return async.sync(function()
		local playlist_name_input = async.wrap(vim.ui.input)
		local playlist_name = async.wait(playlist_name_input({ prompt = "Playlist name: " }))

		if not playlist_name then
			vim.notify("Cancelled")
			return
		end
	end)
end

return M
