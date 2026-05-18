local M = {}

-- note: MODULES

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")
local controller = require("yt-playlist.controller")
local local_state = require("yt-playlist.local_state")

---@type MpvModule
local mpv = require("yt-playlist.mpv")

---@type MusicModule
local music = require("yt-playlist.music")

---@type TimerModule
local timer = require("yt-playlist.timer")

---@type UiModule
local ui = require("yt-playlist.ui")

---@type AsyncModule
local async = require("yt-playlist.async")

---@type PlaylistModule
local playlist = require("yt-playlist.playlist")

---@type DbModule
local db = require("yt-playlist.db")

---@type CommonModule
local common = require("yt-playlist.common")

local function setup_global_state()
	return async.sync(function()
		async.wait(db.setup())
		async.wait(local_state.setup())
		async.wait(music.setup())
		async.wait(playlist.setup())

		async.wait(common.sync_files_with_all())

		async.wait(controller.update_files())
	end)
end

-- note: SETUP

function M.setup()
	vim.api.nvim_create_user_command("YtPlayList", function()
		async.sync(function()
			if global_state.state.is_open then
				ui.hide_playlist()
				return
			end

			require("yt-playlist.autocmd")
			require("yt-playlist.command_config").setup()

			async.wait(setup_global_state())

			ui.show_playlist()

			require("yt-playlist.keymaps").setup()

			local result = async.wait(mpv.ensure_mpv())

			if result then
				vim.print("Connected to mpv")

				async.wait(ui.update_ui())
			end

			-- note: start timers
			vim.schedule(function()
				timer.start_position_timer()
				timer.start_fs_event_timer()
				timer.start_mpv_listener()
			end)
		end)()
	end, {})
end

return M
