---@class UiModule
---@field update_ui fun(): AsyncThunk
---@field update_playlist_buf fun(): nil
---@field update_info_buf fun(): nil
---@field update_volume_buf fun(): nil
---@field show_playlist fun(): nil
---@field hide_playlist fun(): nil
---@field toggle_ui fun(): nil
---@field switch_tab fun(): nil
local M = {}

-- note: MODULES

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")
local local_state = require("yt-playlist.local_state")

---@type UtilModule
local util = require("yt-playlist.util")

---@type AsyncModule
local async = require("yt-playlist.async")

---@type StopTimerModule
local stop_timer = require("yt-playlist.stop_timer")

---@type ConstantsModule
local constants = require("yt-playlist.constants")

---@type DbModule
local db = require("yt-playlist.db")

-- note: LOCAL VARIABLES
local TOTAL_WIDTH = constants.TOTAL_WIDTH
local UPPER_HEIGHT = constants.UPPER_HEIGHT
local INFO_WIDTH = constants.INFO_WIDTH
local LOWER_HEIGHT = constants.LOWER_HEIGHT
local VOLUME_WIDTH = constants.VOLUME_WIDTH

-- note: LOCAL FUNCTIONS
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

	table.insert(
		lines,
		"  [Enter] Play  |  [A-p] Play/Pause  |  [A-j] Next  |  [A-k] Prev  |  [A-d] Download  |  [A-t] Switch tab "
	)
	table.insert(
		lines,
		"  ------------------------------------------------------------------------------------------------------- "
	)
	table.insert(lines, "  [A-h] Rewind  |  [A-l] Forward  |  [A-m] Switch Mode  |  [A-x] Remove  |  [q] Quit ")

	-- todo: change here
	vim.api.nvim_buf_set_lines(global_state.state.info_buf, 0, -1, false, lines)
	vim.bo[global_state.state.info_buf].modifiable = false
end

-- quit with q and C-c
local function set_buf_keymap()
	vim.api.nvim_buf_set_keymap(global_state.state.playlist_buf, "n", "q", "", {
		callback = function()
			M.toggle_ui()
		end,
	})

	vim.api.nvim_buf_set_keymap(global_state.state.playlist_buf, "n", "<C-c>", "", {
		callback = function()
			M.toggle_ui()
		end,
	})
end

local function create_playlist_win()
	if not global_state.state.playlist_buf then
		global_state.state.playlist_buf = vim.api.nvim_create_buf(false, true)
	end

	global_state.state.playlist_win = vim.api.nvim_open_win(global_state.state.playlist_buf, true, {
		title = global_state.current_playlist or "Play list",
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
	if not global_state.state.info_buf then
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
	if not global_state.state.volume_buf then
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

local function render_songs()
	vim.schedule(function()
		local buf = global_state.state.playlist_buf

		if not buf then
			return
		end

		local win = vim.fn.bufwinid(buf)

		if win == -1 then
			return
		end

		local cursor = vim.api.nvim_win_get_cursor(win)

		vim.api.nvim_buf_clear_namespace(buf, global_state.song_ns, 2, -1)

		local song_files = global_state.files

		local songs = {}

		for _, song in ipairs(song_files) do
			table.insert(songs, song.filename)
		end

		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 2, -1, false, songs)

		local state = local_state.load_state()

		-- highlight current song
		if state and state.current_playlist == global_state.current_playlist then
			for i, song in ipairs(songs) do
				local is_current = song == global_state.player_state.title

				vim.api.nvim_buf_set_extmark(buf, global_state.song_ns, i + 1, 0, {
					hl_group = is_current and "Title" or "",
					end_col = #song,
				})
			end
		end

		vim.bo[buf].modifiable = false

		if vim.api.nvim_win_is_valid(win) then
			local line_count = vim.api.nvim_buf_line_count(buf)
			local row = math.min(cursor[1], line_count)
			vim.api.nvim_win_set_cursor(win, { row, cursor[2] })
		end
	end)
end

local function render_playlists()
	vim.schedule(function()
		local buf = global_state.state.playlist_buf

		if not buf then
			return
		end

		local win = vim.fn.bufwinid(buf)

		if win == -1 then
			return
		end

		local cursor = vim.api.nvim_win_get_cursor(win)

		---@type string[]
		local playlist_lines = {}

		global_state.line_metadata = {}

		local all_songs = db.load_songs()

		local all_songs_text = #all_songs > 1 and " songs" or " song"
		local all_line = "All (" .. #all_songs .. all_songs_text .. ")"

		global_state.line_metadata[1] = { name = "All", display_name = all_line }

		for i, playlist in ipairs(global_state.playlists) do
			local number_of_songs = #playlist.songs
			local song_text = number_of_songs > 1 and " songs" or " song"
			local line = playlist.name .. " (" .. number_of_songs .. song_text .. ")"

			table.insert(playlist_lines, line)

			-- setting line metadata
			global_state.line_metadata[i + 1] = { name = playlist.name, display_name = line }
		end

		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 2, 3, false, { all_line })
		vim.api.nvim_buf_set_lines(buf, 3, -1, false, playlist_lines)

		-- highlight current playlist
		local state = local_state.load_state()
		local playlists = global_state.line_metadata

		for i, playlist in ipairs(playlists) do
			local is_current = state and playlist.name == state.current_playlist

			vim.api.nvim_buf_set_extmark(buf, global_state.playlist_ns, i + 1, 0, {
				hl_group = is_current and "Title" or "",
				end_col = #playlist.display_name,
			})
		end

		vim.bo[buf].modifiable = false

		if vim.api.nvim_win_is_valid(win) then
			local line_count = vim.api.nvim_buf_line_count(buf)
			local row = math.min(cursor[1], line_count)
			vim.api.nvim_win_set_cursor(win, { row, cursor[2] })
		end
	end)
end

-- note: EXPORT FUNCTIONS

function M.update_ui()
	return async.sync(function()
		async.wait(M.update_playlist_buf())

		M.update_info_buf()

		M.update_volume_buf()
	end)
end

function M.update_playlist_buf()
	return async.sync(function()
		vim.schedule(function()
			local buf = global_state.state.playlist_buf
			local line_count = buf and vim.api.nvim_buf_line_count(buf)

			if not global_state.state.playlist_buf then
				global_state.state.playlist_buf = vim.api.nvim_create_buf(false, true)
			end

			-- initialize playlist buf
			if line_count <= 1 then
				-- Create tabs
				local line = ""
				local tab_positions = {}
				for _, tab in ipairs(global_state.tabs) do
					local label = tab .. "  "
					table.insert(tab_positions, { start = #line, len = #label, name = tab })
					line = line .. label .. " "
				end

				vim.api.nvim_buf_set_lines(global_state.state.playlist_buf, 0, 1, false, { line })

				vim.api.nvim_buf_set_lines(
					global_state.state.playlist_buf,
					1,
					2,
					false,
					{ string.rep("─", constants.TOTAL_WIDTH) }
				)
			end

			-- update tab
			vim.api.nvim_buf_clear_namespace(global_state.state.playlist_buf, global_state.playlist_tabs_ns, 0, 1)

			local line = ""
			local tab_positions = {}
			for _, tab in ipairs(global_state.tabs) do
				local label = tab .. "  "
				table.insert(tab_positions, { start = #line, len = #label, name = tab })
				line = line .. label .. " "
			end

			-- highlight tab
			for _, pos in ipairs(tab_positions) do
				local hl = pos.name == global_state.current_tab and "Title" or "Comment"
				vim.api.nvim_buf_set_extmark(
					global_state.state.playlist_buf,
					global_state.playlist_tabs_ns,
					0,
					pos.start,
					{
						end_col = pos.start + pos.len,
						hl_group = hl,
					}
				)
			end
		end)

		if global_state.current_tab == "Songs" then
			render_songs()
		else
			render_playlists()
		end
	end)
end

function M.update_info_buf()
	local buf = global_state.state.info_buf
	-- if playlist is not opened: do not need to update ui
	if not buf or buf == -1 then
		return
	end

	vim.schedule(function()
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
	end)
end

function M.update_volume_buf()
	local buf = global_state.state.volume_buf

	if not buf then
		return
	end

	vim.schedule(function()
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
	end)
end

function M.show_playlist()
	global_state.state.is_open = true

	vim.schedule(function()
		create_playlist_win()
		create_info_win()
		create_volume_win()
		set_buf_keymap()
	end)
end

function M.hide_playlist()
	stop_timer.stop_position_timer()
	-- stop_timer.stop_fs_event_timer() -- todo: may remove

	global_state.state.is_open = false

	vim.api.nvim_win_hide(global_state.state.playlist_win)
	vim.api.nvim_win_hide(global_state.state.info_win)
	vim.api.nvim_win_hide(global_state.state.volume_win)

	global_state.state.playlist_win = nil
	global_state.state.info_win = nil
	global_state.state.volume_win = nil
end

function M.toggle_ui()
	-- hide
	if global_state.state.is_open then
		M.hide_playlist()
	else
		M.show_playlist()
	end
end

function M.switch_tab()
	return async.sync(function()
		if global_state.current_tab == "Songs" then
			global_state.current_tab = "Playlists"

			vim.api.nvim_win_set_config(global_state.state.playlist_win, {
				title = "Choose a playlist",
			})
		else
			global_state.current_tab = "Songs"

			vim.api.nvim_win_set_config(global_state.state.playlist_win, {
				title = global_state.current_playlist,
			})
		end

		async.wait(M.update_playlist_buf())
	end)
end

return M
