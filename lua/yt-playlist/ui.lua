---@class UiModule
---@field update_info_buf fun(): nil
---@field update_playlist_buf fun(): nil
---@field update_ui fun(): nil
---@field get_current_song_and_update_ui fun(): nil
---@field draw_volume_string fun(): string
---@field update_volume_buf fun(): nil
local M = {}

-- note: MODULES

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type CommonModule
local common = require("yt-playlist.common")

---@type UtilModule
local util = require("yt-playlist.util")

---@type MusicModule
local music = require("yt-playlist.music")

local constants = require("yt-playlist.constants")

-- note: LOCAL VARIABLES
local LOWER_HEIGHT = constants.LOWER_HEIGHT
local VOLUME_WIDTH = constants.VOLUME_WIDTH

function M.update_info_buf()
	local buf = global_state.state.info_buf
	-- if playlist is not opened: do not need to update ui
	if not buf or buf == -1 then
		return
	end
	-- global_state.state.info_buf not ready setup
	if not buf or not vim.api.nvim_buf_is_valid(buf) or #vim.api.nvim_buf_get_lines(buf, 0, -1, false) < 3 then
		return
	end

	vim.api.nvim_buf_clear_namespace(buf, global_state.info_ns, 0, -1)

	local title = global_state.player_state.title
	local position = global_state.player_state.position
	local duration = global_state.player_state.duration
	local paused = global_state.player_state.paused
	local mode = global_state.player_state.mode
	-- local volume = global_state.player_state.volume

	-- line 0: song title
	vim.api.nvim_buf_set_extmark(buf, global_state.info_ns, 0, 0, {
		virt_text = { { title or "-" } },
		virt_text_pos = "eol", -- appends after the line text
	})

	local pause_text = title == nil and "No song selected" or (paused and "⏸ Paused" or "▶ Playing")
	-- line 1: status
	vim.api.nvim_buf_set_extmark(buf, global_state.info_ns, 1, 0, {
		virt_text = { { pause_text } },
		virt_text_pos = "eol",
	})

	-- line 2: time
	vim.api.nvim_buf_set_extmark(buf, global_state.info_ns, 2, 0, {
		virt_text = { { string.format("%s / %s", util.format_time(position), util.format_time(duration)) } },
		virt_text_pos = "eol",
	})

	local mode_icons = {
		normal = "▶ Normal",
		loop = "🔂 Loop",
		random = "🔀 Random",
	}

	-- line 3: mode
	vim.api.nvim_buf_set_extmark(buf, global_state.info_ns, 3, 0, {
		virt_text = { { mode_icons[mode or "normal"], "Normal" } },
		virt_text_pos = "eol",
	})
end

function M.update_playlist_buf()
	local buf = global_state.state.playlist_buf

	if not buf then
		return
	end

	local win = vim.fn.bufwinid(buf)

	-- do not need to update ui
	if win == -1 then
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(win)

	vim.api.nvim_buf_clear_namespace(buf, global_state.playlist_ns, 0, -1)

	-- note: update file in music
	music.update_files()
	local song_files = music.get_files()

	local songs = {}

	for _, song in ipairs(song_files) do
		table.insert(songs, song.filename)
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, songs)

	-- highlight current song
	for i, song in ipairs(songs) do
		local is_current = song == global_state.player_state.title

		vim.api.nvim_buf_set_extmark(buf, global_state.playlist_ns, i - 1, 0, {
			hl_group = is_current and "Title" or "",
			end_col = #song,
		})
	end

	vim.bo[buf].modifiable = false

	if vim.api.nvim_win_is_valid(win) then
		local line_count = vim.api.nvim_buf_line_count(buf)
		local row = math.min(cursor[1], line_count)
		vim.api.nvim_win_set_cursor(win, { row, cursor[2] })
	end
end

function M.update_volume_buf()
	local buf = global_state.state.volume_buf

	if not buf then
		return
	end

	local win = vim.fn.bufwinid(buf)

	-- do not need to update ui
	if win == -1 then
		return
	end

	local function center_text(text, width)
		-- local text_width = vim.fn.strwidth(text)
		local str_width = vim.fn.strwidth(text)
		local text_width = str_width % 2 == 0 and str_width or str_width + 1
		local padding = math.floor(width / 2) - math.floor(text_width / 2)
		return string.rep(" ", padding) .. text
	end

	local function draw_volume()
		local volume = global_state.player_state.volume or 0

		-- reserve last 2 lines for controls and volume number
		local bar_height = (LOWER_HEIGHT - 4) * 2
		local filled = math.floor((volume / 100) * bar_height)
		local empty = bar_height - filled

		local lines = {}

		-- volume number at top
		table.insert(lines, center_text(string.format("%d%%", volume), VOLUME_WIDTH))
		table.insert(lines, "")

		-- empty part (top)
		for i = 1, math.ceil(empty / 2) do
			if empty - (i * 2) < 0 then
				table.insert(lines, center_text("█░", VOLUME_WIDTH))
			else
				table.insert(lines, center_text("░░", VOLUME_WIDTH))
			end
		end

		-- filled part (bottom)
		for i = math.ceil(filled / 2), 1, -1 do
			if filled - (i * 2) >= 0 then
				table.insert(lines, center_text("██", VOLUME_WIDTH))
			end
		end

		-- controls at bottom
		table.insert(lines, "")
		table.insert(lines, center_text("- / + ", VOLUME_WIDTH))

		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
	end

	draw_volume()
end

function M.update_ui()
	M.update_info_buf()
	M.update_playlist_buf()
	M.update_volume_buf()

	local title = global_state.player_state.title
	local paused = global_state.player_state.paused

	-- todo: change later
	-- if title and not paused then
	-- 	vim.notify("Now playing: " .. title)
	-- end
end

function M.get_current_song_and_update_ui()
	music.get_current_song(function(info)
		vim.schedule(function()
			common.update_player_state(info)

			M.update_ui()

			vim.bo[global_state.state.info_buf].modifiable = false
		end)
	end)
end

function M.draw_volume_string()
	return string.rep("=", 10)
end

return M
