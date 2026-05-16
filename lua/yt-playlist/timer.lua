---@class TimerModule
---@field start_fs_event_timer fun(): nil
---@field start_position_timer fun(): nil
---@field start_mpv_listener fun(): nil
local M = {}

-- note: MODULE

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type UiModule
local ui = require("yt-playlist.ui")

---@type MusicModule
local music = require("yt-playlist.music")

---@type AsyncModule
local async = require("yt-playlist.async")

---@type ControllerModule
local controller = require("yt-playlist.controller")

---@type CommonModule
local common = require("yt-playlist.common")

---@type StopTimerModule
local stop_timer = require("yt-playlist.stop_timer")

---@type ConstantsModule
local constants = require("yt-playlist.constants")

---@type DbModule
local db = require("yt-playlist.db")

---@type PlaylistModule
local playlist = require("yt-playlist.playlist")

-- note: LOCAL FUNCTIONS
local function send(handle, cmd)
	handle:write(vim.json.encode(cmd) .. "\n")
end

function M.start_fs_event_timer()
	stop_timer.stop_fs_event_timer()

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

					-- note:
					-- if addition / remove happened in Music directory
					-- 1. sync db.json with files
					-- 2. sync mpv playlist with db.json
					-- 3. sync playlists.json with files
					-- 4. update global_state.files
					-- 5. update ui
					async.sync(function()
						local all_files = controller.get_all_files()

						db.sync_db(all_files)
						async.wait(controller.sync_playlist())
						playlist.sync_playlists()
						async.wait(controller.update_files())
						async.wait(common.get_current_song_and_update_ui())
					end)()
				end)
			)
		end)
	)
end

function M.start_position_timer()
	if global_state.timer.position_timer then
		stop_timer.stop_position_timer()
	end

	global_state.timer.position_timer = vim.loop.new_timer()

	global_state.timer.position_timer:start(0, 1000, function()
		if global_state.player_state.position and not global_state.player_state.paused then
			-- update song time-pos every second in info_buf
			global_state.player_state.position = math.floor(global_state.player_state.position) + 1
			ui.update_info_buf()
		end
	end)
end

function M.start_mpv_listener()
	stop_timer.stop_mpv_listener()

	local handle = vim.loop.new_pipe(false)
	local playlist_timer = vim.uv.new_timer()

	if not handle then
		-- todo: may handle this
		return nil
	end

	handle:connect("/tmp/mpv.sock", function(err)
		if err then
			return
		end

		-- send observe_property command
		send(handle, { command = { "observe_property", 1, "playlist-pos" } })
		send(handle, { command = { "observe_property", 2, "volume" } })
		send(handle, { command = { "observe_property", 3, "pause" } })
		send(handle, { command = { "observe_property", 4, "playlist-count" } })
		-- send(handle, { command = { "observe_property", 4, "time-pos" } })

		-- listen for incoming events
		handle:read_start(function(read_err, data)
			if read_err or not data then
				return
			end

			-- split events by new line
			for line in data:gmatch("[^\n]+") do
				if line ~= "" then
					local ok, event = pcall(vim.json.decode, line)

					if not ok then
						return
					end

					-- note: update volume buf when volume is adjusted
					if event.event == "property-change" and event.name == "volume" then
						common.update_player_state({ volume = event.data })
						ui.update_volume_buf()
					end

					-- note: update playlist and info when song position is updated
					if event.event == "property-change" and event.name == "playlist-pos" then
						if playlist_timer then
							playlist_timer:stop()

							playlist_timer:start(
								100,
								0,
								vim.schedule_wrap(function()
									async.sync(function()
										local info = async.wait(music.get_current_song())
										common.update_player_state(info)

										ui.update_info_buf()
										async.wait(ui.update_playlist_buf())

										if global_state.player_state and global_state.player_state.title then
											vim.schedule(function()
												vim.notify("Now playing: " .. global_state.player_state.title)
											end)
										end
									end)()
								end)
							)
						end
					end

					-- note: update info buf when rewind / forward
					if event.event == "seek" then
						async.sync(function()
							local info = async.wait(music.get_current_song())
							common.update_player_state(info)

							ui.update_info_buf()
						end)()
					end

					if event.event == "property-change" and event.name == "playlist-count" then
						local playlist_count = event.data

						-- no more song in mpv playlist -> update global_state.player_state
						if playlist_count == 0 then
							common.reset_player_state()
						end
					end
				end
			end
		end)
	end)

	global_state.timer.mpv_listener = handle
end

return M
