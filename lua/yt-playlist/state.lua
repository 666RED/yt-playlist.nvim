---@class StateModule
---@field state YtPlaylistState
---@field timer YtPlaylistTimer
---@field stop_posotion_timer fun(): nil
---@field update_info_buf fun(): nil
---@field start_position_timer fun(): nil
---@field show_playlist fun(): nil
---@field hide_playlist fun(): nil
---@field render fun(): nil
---@field toggle_ui fun(): nil
---@field get_current_song_and_update_info_ui fun(): nil
local M = {}

-- note: MODULES

---@type UtilModule
local util = require("yt-playlist.util")

---@type MusicModule
local music = require("yt-playlist.music")

-- note: VARIABLES

local ns = vim.api.nvim_create_namespace("yt_info")

---@type YtPlaylistState
M.state = { playlist_win = nil, info_win = nil, playlist_buf = nil, info_buf = nil, is_open = false }

---@type YtPlaylistTimer
M.timer = { position_timer = nil, fs_event_timer = nil }

---@type PlayerState
M.player_state = {
	title = nil,
	duration = nil,
	paused = nil,
	position = nil,
}

-- note: LOCAL FUNCTIONS

local function toggle_ui()
	-- hide
	if M.state.is_open then
		M.hide_playlist()
	else
		M.show_playlist()
	end
end

local function setup_info_buf()
	vim.bo[M.state.info_buf].modifiable = true
	vim.api.nvim_buf_set_lines(M.state.info_buf, 0, -1, false, {
		"  Now Playing :", -- line 0
		"  Status      :", -- line 1
		"  Time        :", -- line 2
		"",
		"",
		"",
		"  [Enter] Play  |  [A-p] Play/Pause  |  [A-j] Next  |  [A-k] Prev ",
		"  -------------------------------------------------------------------------------- ",
		"  [A-h] Rewind  |  [A-l] Forward  |  [A-s] Shuffle  |  [A-d] Download  |  [q] Quit ",
	})
	vim.bo[M.state.info_buf].modifiable = false
end

local function set_buf_keymap()
	vim.api.nvim_buf_set_keymap(M.state.playlist_buf, "n", "q", "", {
		callback = function()
			toggle_ui()
		end,
	})

	vim.api.nvim_buf_set_keymap(M.state.playlist_buf, "n", "<C-c>", "", {
		callback = function()
			toggle_ui()
		end,
	})
end

---@param total_width integer
---@param upper_height integer
local function create_playlist_win(total_width, upper_height)
	if not M.state.playlist_buf or not vim.api.nvim_buf_is_valid(M.state.playlist_buf) then
		M.state.playlist_buf = vim.api.nvim_create_buf(false, true)

		local song_files = music.get_files()

		local songs = {}

		for _, song in ipairs(song_files) do
			table.insert(songs, song.filename)
		end

		vim.api.nvim_buf_set_lines(M.state.playlist_buf, 0, -1, false, songs)

		vim.bo[M.state.playlist_buf].modifiable = false

		-- use :q to quit instead of q or <C-c>
		vim.api.nvim_create_autocmd("QuitPre", {
			buffer = M.state.playlist_buf,
			callback = function()
				if M.state.info_buf ~= nil and vim.api.nvim_win_is_valid(M.state.info_win) then
					vim.api.nvim_win_hide(M.state.info_win)
					M.state.info_buf = nil
					M.state.is_open = false
					M.stop_position_timer()
					M.stop_fs_event_timer()
					return
				end
			end,
		})

		require("yt-playlist.music_keymaps").setup(M.state.playlist_buf)
	end

	M.state.playlist_win = vim.api.nvim_open_win(M.state.playlist_buf, true, {
		title = "Play list",
		title_pos = "center",
		relative = "editor",
		row = 0,
		col = 0,
		width = total_width,
		height = upper_height - 2,
	})

	util.set_win_opts(M.state.playlist_win)
end

---@param upper_height integer
---@param total_width integer
---@param lower_height integer
local function create_info_win(upper_height, total_width, lower_height)
	if not M.state.info_buf or not vim.api.nvim_buf_is_valid(M.state.info_buf) then
		M.state.info_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[M.state.info_buf].modifiable = false
	end

	vim.bo[M.state.info_buf].modifiable = true
	-- vim.api.nvim_buf_set_lines(state.info_buf, 0, -1, false, {
	-- 	current_song,
	-- })

	vim.bo[M.state.info_buf].modifiable = false

	M.state.info_win = vim.api.nvim_open_win(M.state.info_buf, false, {
		relative = "editor",
		row = upper_height,
		col = 0,
		width = total_width,
		height = lower_height,
		focusable = false,
	})

	util.set_win_opts(M.state.info_win)

	setup_info_buf()

	vim.wo[M.state.info_win].cursorline = false -- turn off cursorline
end

local function get_current_song_and_update_ui()
	music.get_current_song(function(info)
		vim.schedule(function()
			vim.bo[M.state.info_buf].modifiable = true

			if info.title and info.position and info.duration then
				M.player_state.title = info.title
				M.player_state.position = info.position
				M.player_state.duration = info.duration
				M.player_state.paused = info.paused
			end

			M.update_info_buf()

			vim.bo[M.state.info_buf].modifiable = false
		end)
	end)
end

-- note: EXPORT FUNCTIONS

function M.stop_position_timer()
	if M.timer.position_timer then
		M.timer.position_timer:stop()
		M.timer.position_timer:close()
		M.timer.position_timer = nil
	end
end

function M.stop_fs_event_timer()
	if M.timer.fs_event_timer then
		M.timer.fs_event_timer:stop()
		M.timer.fs_event_timer:close()
		M.timer.fs_event_timer = nil
	end
end

function M.update_info_buf()
	-- M.state.info_buf not ready setup
	if
		not M.state.info_buf
		or not vim.api.nvim_buf_is_valid(M.state.info_buf)
		or #vim.api.nvim_buf_get_lines(M.state.info_buf, 0, -1, false) < 3
	then
		return
	end

	vim.api.nvim_buf_clear_namespace(M.state.info_buf, ns, 0, -1)

	local title = M.player_state.title
	local position = M.player_state.position
	local duration = M.player_state.duration
	local paused = M.player_state.paused

	-- line 0: song title
	vim.api.nvim_buf_set_extmark(M.state.info_buf, ns, 0, 0, {
		virt_text = { { title or "-" } },
		virt_text_pos = "eol", -- appends after the line text
	})

	local pause_text = paused == nil and "No song selected" or (paused and "⏸ Paused" or "▶ Playing")
	-- line 1: status
	vim.api.nvim_buf_set_extmark(M.state.info_buf, ns, 1, 0, {
		virt_text = { { pause_text } },
		virt_text_pos = "eol",
	})

	-- line 2: time
	vim.api.nvim_buf_set_extmark(M.state.info_buf, ns, 2, 0, {
		virt_text = { { string.format("%s / %s", util.format_time(position), util.format_time(duration)) } },
		virt_text_pos = "eol",
	})
end

function M.start_position_timer()
	if M.timer.position_timer then
		M.stop_position_timer()
	end

	M.timer.position_timer = vim.loop.new_timer()

	M.timer.position_timer:start(0, 1000, function()
		if M.player_state.position then
			-- song finished
			if math.floor(M.player_state.position) >= math.floor(M.player_state.duration) then
				M.timer.position_timer:stop()

				get_current_song_and_update_ui()
				M.timer.position_timer:again()
			else
				M.player_state.position = M.player_state.position + 1
			end
		end

		vim.schedule(function()
			M.update_info_buf()
		end)
	end)
end

function M.show_playlist()
	M.state.is_open = true
	local total_width = vim.o.columns
	local total_height = vim.o.lines - vim.o.cmdheight - 1
	local upper_height = math.floor(total_height * 0.7)
	local lower_height = total_height - upper_height

	create_playlist_win(total_width, upper_height)
	create_info_win(upper_height, total_width, lower_height)

	set_buf_keymap()
end

function M.hide_playlist()
	M.stop_position_timer()
	M.stop_fs_event_timer()
	M.state.is_open = false
	vim.api.nvim_win_hide(M.state.playlist_win)
	vim.api.nvim_win_hide(M.state.info_win)
	M.state.playlist_win = nil
	M.state.info_win = nil
end

function M.render()
	local buf = M.state.playlist_buf

	if not buf then
		-- todo: handle this later
		return
	end

	local win = vim.fn.bufwinid(buf)
	local cursor = vim.api.nvim_win_get_cursor(win)

	-- note: update file in music
	music.update_files()
	local song_files = music.get_files()

	local songs = {}

	for _, song in ipairs(song_files) do
		table.insert(songs, song.filename)
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, songs)
	vim.bo[buf].modifiable = false

	if vim.api.nvim_win_is_valid(win) then
		local line_count = vim.api.nvim_buf_line_count(buf)
		local row = math.min(cursor[1], line_count)
		vim.api.nvim_win_set_cursor(win, { row, cursor[2] })
	end
end

M.toggle_ui = toggle_ui
M.get_current_song_and_update_ui = get_current_song_and_update_ui

return M
