---@class MusicModule
---@field sync_playlist fun(): AsyncThunk<nil>
---@field get_files fun(): Song_File[]
---@field update_files fun(): AsyncThunk<nil>
---@field get_current_song fun(): AsyncThunk<PlayerState>
---@field play_song fun(file: string): AsyncThunk<nil>
---@field pause_or_resume fun(): AsyncThunk<boolean>
---@field next_song fun(): AsyncThunk<nil>
---@field prev_song fun(): AsyncThunk<nil>
---@field rewind fun(): AsyncThunk<nil>
---@field forward fun(): AsyncThunk<nil>
---@field increase_volume fun(volume?: integer): AsyncThunk<nil>
---@field decrease_volume fun(volume?: integer): AsyncThunk<nil>
---@field download_song fun(): nil
---@field delete_song fun(file: string): function
---@field switch_mode fun(): function
---@field sync_mpv_ids fun(): function
local M = {}

---@type Song_File[]
local files = {}

---@type PlayMode[]
local modes = { "normal", "loop", "random" }

-- note: MODULES

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type MpvModule
local mpv = require("yt-playlist.mpv")

---@type UtilModule
local util = require("yt-playlist.util")

---@type DataModule
local local_state = require("yt-playlist.data")

---@type AsyncModule
local async = require("yt-playlist.async")

local constants = require("yt-playlist.constants")

-- note: LOCAL FUNCTIONS

---@return string[]
local function get_all_files()
	local all_files = {}

	for _, ext in ipairs(constants.MUSIC_EXTENSIONS) do
		local pattern = constants.MUSIC_PATH .. "/*." .. ext
		local music_files = vim.split(vim.fn.glob(pattern), "\n", { trimempty = true })
		vim.list_extend(all_files, music_files)
	end

	return all_files
end

local function build_cmd(url, opts)
	local cmd = {
		"yt-dlp",
		"--extract-audio",
		"--audio-format",
		opts.format,
		"--audio-quality",
		opts.quality,
		"-o",
		opts.name ~= "" and constants.MUSIC_PATH .. "/" .. opts.name .. ".%(ext)s"
			or constants.MUSIC_PATH .. "/%(title)s.%(ext)s",
	}

	table.insert(cmd, url)
	return cmd
end

---@param original_files Song_File[]
---@return AsyncThunk<nil>
local function insert_new_song(original_files)
	return async.sync(function()
		local is_random = global_state.player_state.mode == "random"
		async.wait(M.update_files())

		for i = 1, #files, 1 do
			-- new song found
			if not original_files[i] or original_files[i].full_name ~= files[i].full_name then
				local fullpath = constants.MUSIC_PATH .. "/" .. files[i].full_name
				if is_random then
					async.wait(mpv.mpv_cmd({ "playlist-unshuffle" }))
					async.wait(mpv.mpv_cmd({ "loadfile", fullpath, "insert-at", i - 1 }))
					async.wait(mpv.mpv_cmd({ "playlist-shuffle" }))
				else
					async.wait(mpv.mpv_cmd({ "loadfile", fullpath, "insert-at", i - 1 }))
				end
				break
			end
		end
	end)
end

---@param file string
---@return Song_File_With_Index|nil
local function get_song_file(file)
	for i, song in ipairs(files) do
		if song.filename == file then
			return vim.tbl_extend("force", song, { index = i })
		end
	end

	return nil
end

---@param index integer
local function play_current_song(index)
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "set_property", "playlist-pos", index }))
		async.wait(mpv.mpv_cmd({ "set_property", "pause", false }))
	end)
end

---@param current PlayMode
---@return PlayMode
local function next_mode(current)
	for i, mode in ipairs(modes) do
		if mode == current then
			return modes[i % #modes + 1]
		end
	end

	return "normal"
end

-- note: EXPORT FUNCTIONS

function M.sync_playlist()
	return async.sync(function()
		local is_random = global_state.player_state.mode == "random"

		if is_random then
			async.wait(mpv.mpv_cmd({ "playlist-unshuffle" }))
		end

		local playlist = async.wait(mpv.mpv_cmd({ "get_property", "playlist" })) or {}

		local mpv_set = {}

		for _, item in ipairs(playlist) do
			mpv_set[util.norm(item.filename)] = true
		end

		local missing = {}

		for index, file in ipairs(files) do
			local fullpath = constants.MUSIC_PATH .. "/" .. file.full_name
			if not mpv_set[util.norm(fullpath)] then
				table.insert(missing, { fullpath = fullpath, index = index })
			end
		end

		-- if no new files
		if #missing == 0 then
			if is_random then
				async.wait(mpv.mpv_cmd({ "playlist-shuffle" }))
			end

			return
		end

		-- append missing files
		for _, item in ipairs(missing) do
			async.wait(mpv.mpv_cmd({ "loadfile", item.fullpath, "append" }))
			local count = async.wait(mpv.mpv_cmd({ "get_property", "playlist-count" }))
			async.wait(mpv.mpv_cmd({ "playlist-move", count - 1, item.index - 1 }))
		end

		if is_random then
			async.wait(mpv.mpv_cmd({ "playlist-shuffle" }))
		end

		playlist = async.wait(mpv.mpv_cmd({ "get_property", "playlist" })) or {}
		vim.print(playlist)
	end)
end

function M.get_files()
	return files
end

function M.update_files()
	return async.sync(function()
		vim.schedule(function()
			files = {}
			local all_files = get_all_files()

			for _, file in ipairs(all_files) do
				table.insert(files, util.get_song_file(file))
			end
		end)

		async.wait(M.sync_mpv_ids())
	end)
end

function M.get_current_song()
	return async.sync(function()
		local title = async.wait(mpv.mpv_cmd({ "get_property", "media-title" }))
		local time_pos = async.wait(mpv.mpv_cmd({ "get_property", "time-pos" }))
		local duration = async.wait(mpv.mpv_cmd({ "get_property", "duration" }))
		local paused = async.wait(mpv.mpv_cmd({ "get_property", "pause" }))
		local volume = async.wait(mpv.mpv_cmd({ "get_property", "volume" }))
		local state = local_state.load_state()

		---@type PlayerState
		return {
			title = title,
			position = time_pos,
			duration = duration,
			paused = paused,
			volume = volume,
			mode = (state and state.mode) or "normal",
		}
	end)
end

function M.play_song(file)
	return async.sync(function()
		local song = get_song_file(file)

		if not song then
			return
		end

		-- check if files and playlist are synced
		local playlist = async.wait(mpv.mpv_cmd({ "get_property", "playlist" })) or {}

		if #playlist == 0 then
			async.wait(M.sync_playlist())

			async.wait(play_current_song(song.index - 1))
		end

		local mpv_index = nil

		for i, item in ipairs(playlist) do
			if item.id == song.mpv_id then
				mpv_index = i - 1 -- 0-based
				break
			end
		end

		if not mpv_index then
			async.wait(M.sync_playlist())
			async.wait(play_current_song(song.index - 1))
			return
		end

		async.wait(play_current_song(song.index - 1))
	end)
end

function M.pause_or_resume()
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "cycle", "pause" }))

		local paused = async.wait(mpv.mpv_cmd({ "get_property", "pause" }))
		return paused
	end)
end

function M.next_song()
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "playlist-next" }))
		async.wait(mpv.mpv_cmd({ "set_property", "pause", false }))
	end)
end

function M.prev_song()
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "playlist-prev" }))
		async.wait(mpv.mpv_cmd({ "set_property", "pause", false }))
	end)
end

function M.rewind()
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "seek", -10 }))
	end)
end

function M.forward()
	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "seek", 10 }))
	end)
end

function M.increase_volume(volume)
	volume = volume or 5

	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "add", "volume", volume }))
	end)
end

function M.decrease_volume(volume)
	volume = volume or 5

	return async.sync(function()
		async.wait(mpv.mpv_cmd({ "add", "volume", -volume }))
	end)
end

function M.download_song()
	return async.sync(function()
		local url_input = async.wrap(vim.ui.input)
		local url = async.wait(url_input({ prompt = "Youtube vidoe url: " }))

		if not url then
			vim.notify("Cancelled")
			return
		end

		local is_valid = url:match("^https?://")

		if not is_valid then
			vim.notify("Invalid URL", vim.log.levels.ERROR)
			return
		end

		local format_select = async.wrap(vim.ui.select)
		local format = async.wait(format_select({ "mp3", "m4a", "opus", "flac" }, { prompt = "Select audio format:" }))

		if not format or format == "" then
			vim.notify("Cancelled")
			return
		end

		local quality_select = async.wrap(vim.ui.select)
		local quality = async.wait(quality_select({ "128k", "192k", "256k", "320k" }, { prompt = "Select quality:" }))

		if not quality or quality == "" then
			vim.notify("Cancelled")
			return
		end

		local name_input = async.wrap(vim.ui.input)
		local name = async.wait(name_input({ prompt = "Name (optional): " }))

		if not name then
			vim.notify("Cancelled")
			return
		end

		local cmd = build_cmd(url, { format = format, quality = quality, name = name })

		local stderr_lines = {}

		local jobstart = function(_, opts)
			return function(step)
				opts = opts or {}

				local old_exit = opts.on_exit

				opts.on_exit = function(job_id, exit_code, event)
					if old_exit then
						old_exit(job_id, exit_code, event)
					end

					step(exit_code)
				end

				vim.fn.jobstart(cmd, opts)
			end
		end

		local exit_code = async.wait(jobstart(cmd, {
			on_stdout = function(_, data, _)
				for _, line in ipairs(data) do
					if line:match("%[download%]") then
						vim.schedule(function()
							vim.notify(line)
						end)
					end
				end
			end,

			on_stderr = function(_, data, _)
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(stderr_lines, line)
					end
				end
			end,
		}))

		if exit_code ~= 0 then
			vim.notify("Download failed")
			return
		end

		async.wait(insert_new_song(files))

		vim.schedule(function()
			vim.notify("Download completed!")
		end)
	end)
end

function M.delete_song(file)
	return async.sync(function()
		local select = async.wrap(vim.ui.select)

		local result = async.wait(select({ "No", "Yes" }, { prompt = "Delete " .. file .. "?" }))

		if not result or result == "No" then
			vim.notify("Cancelled")
			return
		end

		local song = get_song_file(file)

		if not song then
			vim.notify("Song not found", vim.log.levels.WARN)
			return
		end

		local fullpath = constants.MUSIC_PATH .. "/" .. song.full_name

		local playlist = async.wait(mpv.mpv_cmd({ "get_property", "playlist" })) or {}

		local mpv_index = nil

		for i, item in ipairs(playlist) do
			if item.id == song.mpv_id then
				mpv_index = i - 1
				break
			end
		end

		async.wait(mpv.mpv_cmd({ "playlist-remove", mpv_index }))

		local ok, err = pcall(vim.fs.rm, fullpath)

		vim.schedule(function()
			if ok then
				vim.notify("Deleted: " .. song.filename)
			else
				vim.notify("Failed to delete file: " .. err)
			end
		end)
	end)
end

function M.switch_mode()
	return async.sync(function()
		local current_mode = local_state.load_state()
		local new_mode = next_mode(current_mode and current_mode.mode or "normal")

		if new_mode == "normal" then
			async.wait(mpv.mpv_cmd({ "set_property", "loop-file", "no" }))
			async.wait(mpv.mpv_cmd({ "playlist-unshuffle" }))
		elseif new_mode == "loop" then
			async.wait(mpv.mpv_cmd({ "set_property", "loop-file", "inf" }))
		else
			async.wait(mpv.mpv_cmd({ "set_property", "loop-file", "no" }))
			async.wait(mpv.mpv_cmd({ "playlist-shuffle" }))
		end

		local_state.save_state({ mode = new_mode })

		return new_mode
	end)
end

function M.sync_mpv_ids()
	return async.sync(function()
		local playlist = async.wait(mpv.mpv_cmd({ "get_property", "playlist" })) or {}

		-- match mpv playlist items with local files by filename
		for _, item in ipairs(playlist) do
			local norm_filename = util.norm(item.filename)

			for _, file in ipairs(files) do
				local fullpath = util.norm(constants.MUSIC_PATH .. "/" .. file.full_name)

				if norm_filename == fullpath then
					file.mpv_id = item.id -- assign mpv id to local file
					break
				end
			end
		end
	end)
end

function M.setup()
	return async.sync(function()
		async.wait(M.update_files())
	end)
end

return M
