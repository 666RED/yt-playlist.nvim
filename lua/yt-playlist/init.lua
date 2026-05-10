local M = {}

-- note: MODULES

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type StateModule
local state = require("yt-playlist.state")

---@type MpvModule
local mpv = require("yt-playlist.mpv")

---@type MusicModule
local music = require("yt-playlist.music")

---@type TimerModule
local timer = require("yt-playlist.timer")

---@type UiModule
local ui = require("yt-playlist.ui")

---@type CommonModule
local common = require("yt-playlist.common")

---@type AsyncModule
local async = require("yt-playlist.async")

-- note: LOCAL FUNCTIONS
local function play_song()
	return async.sync(function()
		local file = vim.api.nvim_get_current_line()

		if file == global_state.player_state.title then
			return nil
		end

		async.wait(music.play_song(file))

		local player_state = async.wait(music.get_current_song())

		common.update_player_state(player_state)

		async.wait(ui.update_ui())
	end)
end

-- note: SETUP

function M.setup()
	vim.api.nvim_create_user_command("YtPlayList", function()
		async.sync(function()
			if global_state.state.is_open then
				state.hide_playlist()
				return
			end

			require("yt-playlist.command_config").setup()

			async.wait(music.setup())

			state.show_playlist()

			local result = async.wait(mpv.ensure_mpv())

			if result then
				vim.print("Connected to mpv")

				async.wait(music.sync_mpv_ids())

				async.wait(ui.get_current_song_and_update_ui())
			end

			-- Enter song
			vim.schedule(function()
				vim.api.nvim_buf_set_keymap(global_state.state.playlist_buf, "n", "<CR>", "", {
					callback = function()
						async.sync(function()
							async.wait(play_song())
						end)()
					end,
				})
			end)

			timer.start_position_timer()

			vim.schedule(function()
				timer.start_fs_event_timer()
			end)

			timer.start_mpv_listener()
		end)()
	end, {})
end

return M
