---@class StateModule
---@field show_playlist fun(): nil
---@field hide_playlist fun(): nil
---@field toggle_ui fun(): nil
local M = {}

-- note: MODULES

---@type UtilModule
local util = require("yt-playlist.util")

---@type MusicModule
local music = require("yt-playlist.music")

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

local constants = require("yt-playlist.constants")

---@type TimerModule
local timer = require("yt-playlist.timer")

-- note: LOCAL CONSTANTS

local TOTAL_WIDTH = constants.TOTAL_WIDTH
local UPPER_HEIGHT = constants.UPPER_HEIGHT
local LOWER_HEIGHT = constants.LOWER_HEIGHT
local INFO_WIDTH = constants.INFO_WIDTH
local VOLUME_WIDTH = constants.VOLUME_WIDTH

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

	local CONTENT_LINES = 7
	local empty_lines = LOWER_HEIGHT - CONTENT_LINES

	local lines = {
		"  Now Playing :", -- line 0
		"  Status      :", -- line 1
		"  Time        :", -- line 2
		"  Mode        :", -- line 3
	}

	for _ = 1, empty_lines do
		table.insert(lines, "")
	end

	table.insert(lines, "  [Enter] Play  |  [A-p] Play/Pause  |  [A-j] Next  |  [A-k] Prev  |  [A-m] Switch mode ")
	table.insert(lines, "  ------------------------------------------------------------------------------------- ")
	table.insert(lines, "  [A-l] Forward  |  [A-x] Remove  |  [A-h] Rewind  |  [A-d] Download  |  [q] Quit ")

	-- todo: change here
	vim.api.nvim_buf_set_lines(global_state.state.info_buf, 0, -1, false, lines)
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

local function create_playlist_win()
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
		width = TOTAL_WIDTH,
		height = UPPER_HEIGHT - 3,
	})

	util.set_win_opts(global_state.state.playlist_win)
end

local function create_info_win()
	if not global_state.state.info_buf or not vim.api.nvim_buf_is_valid(global_state.state.info_buf) then
		global_state.state.info_buf = vim.api.nvim_create_buf(false, true)

		setup_info_buf()

		vim.bo[global_state.state.info_buf].modifiable = false
	end

	global_state.state.info_win = vim.api.nvim_open_win(global_state.state.info_buf, false, {
		style = "minimal",
		relative = "editor",
		row = UPPER_HEIGHT - 1,
		col = 0,
		width = INFO_WIDTH,
		height = LOWER_HEIGHT,
		focusable = false,
	})

	util.set_win_opts(global_state.state.info_win)

	vim.wo[global_state.state.info_win].cursorline = false -- turn off cursorline
end

local function create_volume_win()
	if not global_state.state.volume_buf or not vim.api.nvim_buf_is_valid(global_state.state.volume_buf) then
		global_state.state.volume_buf = vim.api.nvim_create_buf(false, true)
	end

	global_state.state.volume_win = vim.api.nvim_open_win(global_state.state.volume_buf, false, {
		style = "minimal",
		relative = "editor",
		row = UPPER_HEIGHT - 1,
		col = INFO_WIDTH + 2,
		width = VOLUME_WIDTH - 2,
		height = LOWER_HEIGHT,
		focusable = false,
	})

	util.set_win_opts(global_state.state.volume_win)
end

-- note: EXPORT FUNCTIONS

function M.show_playlist()
	global_state.state.is_open = true

	create_playlist_win()
	create_info_win()
	create_volume_win()

	set_buf_keymap()
end

function M.hide_playlist()
	timer.stop_position_timer()
	timer.stop_fs_event_timer()
	timer.stop_mpv_listener()

	global_state.state.is_open = false

	vim.api.nvim_win_hide(global_state.state.playlist_win)
	vim.api.nvim_win_hide(global_state.state.info_win)
	vim.api.nvim_win_hide(global_state.state.volume_win)

	global_state.state.playlist_win = nil
	global_state.state.info_win = nil
	global_state.state.volume_win = nil
end

M.toggle_ui = toggle_ui

return M
