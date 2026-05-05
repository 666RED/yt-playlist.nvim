---
---@class StateModule
---@field show_playlist fun(): nil
---@field hide_playlist fun(): nil
---@field toggle_ui fun(): nil
---@field update_player_state fun(data: PlayerState): nil
local M = {}

-- note: MODULES

---@type UtilModule
local util = require("yt-playlist.util")

---@type MusicModule
local music = require("yt-playlist.music")

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type TimerModule
local timer = require("yt-playlist.timer")

-- note: LOCAL FUNCTIONS

local function toggle_ui()
	-- hide
	if global_state.state.is_open then
		M.hide_playlist()
	else
		M.show_playlist()
	end
end

local function setup_info_buf()
	vim.bo[global_state.state.info_buf].modifiable = true
	vim.api.nvim_buf_set_lines(global_state.state.info_buf, 0, -1, false, {
		"  Now Playing :", -- line 0
		"  Status      :", -- line 1
		"  Time        :", -- line 2
		"  Volume      :", -- line 3
		"  Mode        :", -- line 4
		"",
		"",
		"  [Enter] Play  |  [A-p] Play/Pause  |  [A-j] Next  |  [A-k] Prev  |  [+] Volume up  |  [-] Volume down ",
		"  ----------------------------------------------------------------------------------------------------- ",
		"  [A-h] Rewind  |  [A-l] Forward  |  [A-x] Remove  |  [A-m] Switch mode  |  [A-d] Download  |  [q] Quit ",
	})
	vim.bo[global_state.state.info_buf].modifiable = false
end

local function set_buf_keymap()
	vim.api.nvim_buf_set_keymap(global_state.state.playlist_buf, "n", "q", "", {
		callback = function()
			toggle_ui()
		end,
	})

	vim.api.nvim_buf_set_keymap(global_state.state.playlist_buf, "n", "<C-c>", "", {
		callback = function()
			toggle_ui()
		end,
	})
end

---@param total_width integer
---@param upper_height integer
local function create_playlist_win(total_width, upper_height)
	if not global_state.state.playlist_buf or not vim.api.nvim_buf_is_valid(global_state.state.playlist_buf) then
		global_state.state.playlist_buf = vim.api.nvim_create_buf(false, true)

		local song_files = music.get_files()

		local songs = {}

		for _, song in ipairs(song_files) do
			table.insert(songs, song.filename)
		end

		vim.api.nvim_buf_set_lines(global_state.state.playlist_buf, 0, -1, false, songs)

		vim.bo[global_state.state.playlist_buf].modifiable = false

		-- use :q to quit instead of q or <C-c>
		vim.api.nvim_create_autocmd("QuitPre", {
			buffer = global_state.state.playlist_buf,
			callback = function()
				if global_state.state.info_buf ~= nil and vim.api.nvim_win_is_valid(global_state.state.info_win) then
					vim.api.nvim_win_hide(global_state.state.info_win)
					global_state.state.info_buf = nil
					global_state.state.is_open = false
					timer.stop_position_timer()
					timer.stop_fs_event_timer()
					return
				end
			end,
		})

		require("yt-playlist.music_keymaps").setup(global_state.state.playlist_buf)
	end

	global_state.state.playlist_win = vim.api.nvim_open_win(global_state.state.playlist_buf, true, {
		title = "Play list",
		title_pos = "center",
		relative = "editor",
		row = 0,
		col = 0,
		width = total_width,
		height = upper_height - 3,
	})

	util.set_win_opts(global_state.state.playlist_win)
end

---@param upper_height integer
---@param total_width integer
---@param lower_height integer
local function create_info_win(upper_height, total_width, lower_height)
	if not global_state.state.info_buf or not vim.api.nvim_buf_is_valid(global_state.state.info_buf) then
		global_state.state.info_buf = vim.api.nvim_create_buf(false, true)

		setup_info_buf()

		vim.bo[global_state.state.info_buf].modifiable = false
	end

	global_state.state.info_win = vim.api.nvim_open_win(global_state.state.info_buf, false, {
		relative = "editor",
		row = upper_height,
		col = 0,
		width = total_width,
		height = lower_height,
		focusable = false,
	})

	util.set_win_opts(global_state.state.info_win)

	vim.wo[global_state.state.info_win].cursorline = false -- turn off cursorline
end

-- note: EXPORT FUNCTIONS

function M.show_playlist()
	global_state.state.is_open = true
	local total_width = vim.o.columns
	local total_height = vim.o.lines - vim.o.cmdheight - 1
	local upper_height = math.floor(total_height * 0.7)
	local lower_height = total_height - upper_height

	create_playlist_win(total_width, upper_height)
	create_info_win(upper_height, total_width, lower_height)

	set_buf_keymap()
end

function M.hide_playlist()
	timer.stop_position_timer()
	timer.stop_fs_event_timer()

	global_state.state.is_open = false

	vim.api.nvim_win_hide(global_state.state.playlist_win)
	vim.api.nvim_win_hide(global_state.state.info_win)

	global_state.state.playlist_win = nil
	global_state.state.info_win = nil
end

function M.update_player_state(info)
	-- check if no song is in the playlist
	vim.schedule(function()
		local current_line = vim.api.nvim_get_current_line()

		if current_line == "" then
			global_state.player_state.title = nil
			global_state.player_state.position = nil
			global_state.player_state.duration = nil
			global_state.player_state.paused = nil
			return
		end
	end)

	-- vim.print(info.mode)

	if info.title then
		global_state.player_state.title = info.title
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

M.toggle_ui = toggle_ui

return M
