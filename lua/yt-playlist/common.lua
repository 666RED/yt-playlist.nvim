---@class CommonModule
---@field update_player_state fun(data: PlayerState): nil
local M = {}

-- note: MODULE

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type UtilModule
local util = require("yt-playlist.util")

function M.update_player_state(info)
	if not info then
		global_state.player_state = {
			title = nil,
			position = nil,
			paused = nil,
			duration = nil,
			mode = nil,
			volume = nil,
		}
		return
	end

	if info.title then
		global_state.player_state.title = util.remove_extension(info.title)
	end

	if info.position then
		global_state.player_state.position = info.position
	end

	if info.paused ~= nil then
		global_state.player_state.paused = info.paused
	end

	if info.duration then
		global_state.player_state.duration = info.duration
	end

	if info.mode then
		global_state.player_state.mode = info.mode
	end

	if info.volume then
		global_state.player_state.volume = info.volume
	end
end

return M
