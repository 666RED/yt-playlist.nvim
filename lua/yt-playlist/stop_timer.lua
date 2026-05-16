---@class StopTimerModule
---@field stop_position_timer fun(): nil
---@field stop_fs_event_timer fun(): nil
---@field stop_mpv_listener fun(): nil
local M = {}

-- note: MODULES

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

function M.stop_position_timer()
	if global_state.timer.position_timer then
		global_state.timer.position_timer:stop()
		global_state.timer.position_timer:close()
		global_state.timer.position_timer = nil
	end
end

function M.stop_fs_event_timer()
	if global_state.timer.fs_event_timer then
		global_state.timer.fs_event_timer:stop()
		global_state.timer.fs_event_timer:close()
		global_state.timer.fs_event_timer = nil
	end
	if global_state.timer.fs_event then
		global_state.timer.fs_event:stop()
		global_state.timer.fs_event = nil
	end
end

function M.stop_mpv_listener()
	if global_state.timer.mpv_listener then
		global_state.timer.mpv_listener:read_stop()
		global_state.timer.mpv_listener = nil
	end
end

return M
