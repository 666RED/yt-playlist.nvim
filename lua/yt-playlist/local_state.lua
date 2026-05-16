---@class LocalStateModule
---@field save_state fun(state: StateData): nil
---@field load_state fun(): StateData|nil
---@field setup fun(): AsyncThunk<nil>
local M = {}

-- note: MODULES

---@type UtilModule
local util = require("yt-playlist.util")

---@type ConstantsModule
local constants = require("yt-playlist.constants")

---@type AsyncModule
local async = require("yt-playlist.async")

-- note: LOCAL VARIABLES

local STATE_FILE = constants.STATE_FILE

-- note: EXPORT FUNCTIONS
function M.save_state(state)
	local previous_state = M.load_state()

	---@type StateData
	local current_state = {}

	if not previous_state then
		current_state = vim.tbl_extend("force", { mode = "normal", current_playlist = "All" }, state)
	else
		current_state = vim.tbl_extend("force", previous_state, state)
	end

	local file = io.open(STATE_FILE, "w")

	if not file then
		vim.notify("Failed to save state", vim.log.levels.ERROR)
		return
	end

	file:write(vim.json.encode(current_state))
	file:close()
end

function M.load_state()
	local file = io.open(STATE_FILE, "r")

	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	local ok, state = pcall(vim.json.decode, content)

	if not ok then
		return nil
	end

	return state
end

function M.setup()
	return async.sync(function()
		util.ensure_file(STATE_FILE)

		local file = io.open(STATE_FILE, "r")

		if not file then
			return
		end

		local content = file:read("*a")
		file:close()

		-- make sure the default content is created
		if content == "" then
			M.save_state({ mode = "normal", current_playlist = "All" })
		end
	end)
end

return M
