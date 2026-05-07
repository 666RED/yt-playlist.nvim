---@class TimerModule
---@field start_fs_event_timer fun(cb: function): nil
---@field stop_position_timer fun(): nil
---@field stop_fs_event_timer fun(): nil
---@field start_position_timer fun(update_info_buf: function): nil
---@field start_mpv_listener fun(): nil
---@field stop_mpv_listener fun(): nil
local M = {}

-- note: MODULE

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type MpvModule
local mpv = require("yt-playlist.mpv")

---@type UiModule
local ui = require("yt-playlist.ui")

---@type MusicModule
local music = require("yt-playlist.music")

---@type CommonModule
local common = require("yt-playlist.common")

local constants = require("yt-playlist.constants")

function M.start_fs_event_timer(cb)
	local fs_event = vim.loop.new_fs_event()
	if not fs_event then
		return
	end

	global_state.timer.fs_event = fs_event

	-- handle add && remove song from the folder to update ui
	fs_event:start(
		vim.fn.expand(constants.MUSIC_PATH),
		{},
		vim.schedule_wrap(function(err, _, _)
			if err then
				return
			end

			-- cancel previous pending call
			if global_state.timer.fs_event_timer then
				global_state.timer.fs_event_timer:stop()
				global_state.timer.fs_event_timer:close()
				global_state.timer.fs_event_timer = nil
			end

			-- only fire after 500ms of no events
			global_state.timer.fs_event_timer = vim.loop.new_timer()
			global_state.timer.fs_event_timer:start(
				500,
				0,
				vim.schedule_wrap(function()
					global_state.timer.fs_event_timer:stop()
					global_state.timer.fs_event_timer:close()
					global_state.timer.fs_event_timer = nil

					-- update ui
					cb()
				end)
			)
		end)
	)
end

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

function M.start_position_timer(update_info_buf)
	if global_state.timer.position_timer then
		M.stop_position_timer()
	end

	global_state.timer.position_timer = vim.loop.new_timer()

	global_state.timer.position_timer:start(0, 1000, function()
		if global_state.player_state.position and not global_state.player_state.paused then
			-- update song time-pos every second in info_buf
			global_state.player_state.position = math.floor(global_state.player_state.position) + 1
			vim.schedule(function()
				update_info_buf()
			end)
		end
	end)
end

function M.start_mpv_listener()
	---@param cb function
	---@return nil
	local function get_current_song_and_update_state_ui(cb)
		vim.defer_fn(function()
			music.get_current_song(function(data)
				vim.schedule(function()
					common.update_player_state(data)
					cb()
				end)
			end)
		end, 10)
	end

	global_state.timer.mpv_listener = mpv.start_mpv_listener({
		update_playlist_buf = function()
			get_current_song_and_update_state_ui(ui.update_playlist_buf)
		end,
		update_info_buf = function()
			get_current_song_and_update_state_ui(ui.update_info_buf)
		end,
		update_volume_buf = function(data)
			vim.schedule(function()
				common.update_player_state(data)
				ui.update_volume_buf()
			end)
		end,
		update_playlist_and_info_buf = function()
			get_current_song_and_update_state_ui(function()
				ui.update_playlist_buf()
				ui.update_info_buf()
			end)
		end,
	})
end

function M.stop_mpv_listener()
	if global_state.timer.mpv_listener then
		global_state.timer.mpv_listener:close()
		global_state.timer.mpv_listener = nil
	end
end

return M
