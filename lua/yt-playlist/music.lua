---@class MusicModule
---@field get_files fun(): Song_File[]
---@field update_files fun(): nil
---@field play_song fun(file: string, cb: fun(data: PlayerState)): nil
---@field add_to_playlist fun(file: string): nil -- todo:
---@field pause_or_resume fun(cb: fun(data: PlayerState): nil): nil
---@field next_song fun(): nil
---@field prev_song fun(): nil
---@field rewind fun(): nil
---@field forward fun(): nil
---@field increase_volume fun(): nil
---@field decrease_volume fun(): nil
---@field sync_playlist fun(cb?: function, shuffle?: boolean): nil
---@field get_current_song fun(cb: fun(data: PlayerState): nil): nil
---@field download_song fun(): nil
---@field delete_song fun(song: string): nil
---@field switch_mode fun(cb: function): nil
---@field sync_mpv_ids fun(): nil
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

local constants = require("yt-playlist.constants")

-- note: LOCAL FUNCTIONS

local function get_files()
	return files
end

local function sync_playlist(cb, shuffle)
	shuffle = shuffle or false

	local is_random = global_state.player_state.mode == "random"

	local function do_sync()
		mpv.mpv_cmd({ "get_property", "playlist" }, function(playlist)
			playlist = playlist or {}

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

			if #missing == 0 then
				if cb then
					if shuffle then
						mpv.mpv_cmd({ "playlist-shuffle" }, function()
							cb()
						end)
					else
						cb()
					end
				end
				return
			end

			-- process sequentially using recursion
			local function process_next(i)
				if i > #missing then
					if cb then
						if shuffle then
							mpv.mpv_cmd({ "playlist-shuffle" }, function()
								cb()
							end)
						else
							cb()
						end
					end
					return
				end

				local item = missing[i]
				mpv.mpv_cmd({ "loadfile", item.fullpath, "append" }, function()
					mpv.mpv_cmd({ "get_property", "playlist-count" }, function(count)
						mpv.mpv_cmd({ "playlist-move", count - 1, item.index - 1 }, function()
							process_next(i + 1) -- process next only after current is done
						end)
					end)
				end)
			end

			process_next(1)
		end)
	end

	if is_random then
		mpv.mpv_cmd({ "playlist-unshuffle" }, function()
			do_sync()
		end)
	else
		do_sync()
	end
end

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

function M.update_files()
	files = {}
	local all_files = get_all_files()

	for _, file in ipairs(all_files) do
		table.insert(files, util.get_song_file(file))
	end

	M.sync_mpv_ids()
end

function M.get_current_song(cb)
	---@type PlayerState
	local info = {}
	local pending = 5

	local function done()
		pending = pending - 1

		if pending <= 0 then
			local_state.load_mode()
			info.mode = local_state.load_mode()
			cb(info)
		end
	end

	mpv.mpv_cmd({ "get_property", "media-title" }, function(data)
		if data then
			info.title = data and util.remove_extension(data) or nil
		else
			pending = 0
		end

		done()
	end)

	mpv.mpv_cmd({ "get_property", "time-pos" }, function(data)
		if data then
			info.position = data
		else
			pending = 0
		end

		done()
	end)

	mpv.mpv_cmd({ "get_property", "duration" }, function(data)
		if data then
			info.duration = data
		else
			pending = 0
		end

		done()
	end)

	mpv.mpv_cmd({ "get_property", "pause" }, function(data)
		if data ~= nil then
			info.paused = data
		else
			pending = 0
		end

		done()
	end)

	mpv.mpv_cmd({ "get_property", "volume" }, function(volume)
		if volume then
			info.volume = volume
		else
			info.volume = 100
		end

		done()
	end)
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
local function insert_new_song(original_files)
	local is_random = global_state.player_state.mode == "random"
	M.update_files()

	for i = 1, #files, 1 do
		-- new song found
		if not original_files[i] or original_files[i].full_name ~= files[i].full_name then
			local fullpath = constants.MUSIC_PATH .. "/" .. files[i].full_name
			if is_random then
				mpv.mpv_cmd({ "playlist-unshuffle" }, function()
					mpv.mpv_cmd({ "loadfile", fullpath, "insert-at", i - 1 }, function()
						mpv.mpv_cmd({ "playlist-shuffle" })
					end)
				end)
				break
			else
				mpv.mpv_cmd({ "loadfile", fullpath, "insert-at", i - 1 })
			end
			break
		end
	end
end

---@param file string
---@return Song_File_With_Index|nil
local function get_song_file(file)
	for i, song in ipairs(files) do
		if song.filename == file then
			local result = vim.tbl_extend("force", song, { index = i })
			return result
		end
	end

	return nil
end

---@param index integer
---@param cb function
local function play_current_song(index, cb)
	mpv.mpv_cmd({ "set_property", "playlist-pos", index }, function()
		mpv.mpv_cmd({ "set_property", "pause", false }, function()
			vim.defer_fn(function()
				M.get_current_song(function(data)
					cb(data)
				end)
			end, 10)
		end)
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

function M.play_song(file, cb)
	local song = get_song_file(file)

	if not song then
		return
	end

	-- check if files and playlist are synced
	mpv.mpv_cmd({ "get_property", "playlist" }, function(playlist)
		-- if playlist is nil or empty
		if not playlist or #playlist == 0 then
			local is_random = global_state.player_state.mode == "random"

			if is_random then
				sync_playlist(function()
					play_current_song(song.index - 1, cb)
				end, true)
			else
				sync_playlist(function()
					play_current_song(song.index - 1, cb)
				end)
			end

			return
		end

		local mpv_index = nil

		for i, item in ipairs(playlist) do
			if item.id == song.mpv_id then
				mpv_index = i - 1 -- 0-based
				break
			end
		end

		if not mpv_index then
			sync_playlist(function()
				play_current_song(song.index - 1, cb)
			end)
			return
		end

		play_current_song(mpv_index, cb)
	end)
end

function M.add_to_playlist(file)
	mpv.mpv_cmd({ "loadfile", file, "append" })
end

function M.pause_or_resume(cb)
	mpv.mpv_cmd({ "cycle", "pause" }, function()
		mpv.mpv_cmd({ "get_property", "pause" }, function(paused)
			cb({ paused = paused })
		end)
	end)
end

function M.next_song()
	mpv.mpv_cmd({ "playlist-next" }, function()
		mpv.mpv_cmd({ "set_property", "pause", false })
	end)
end

function M.prev_song()
	mpv.mpv_cmd({ "playlist-prev" }, function()
		mpv.mpv_cmd({ "set_property", "pause", false })
	end)
end

function M.rewind()
	mpv.mpv_cmd({ "seek", -10 })
end

function M.forward()
	mpv.mpv_cmd({ "seek", 10 })
end

function M.increase_volume()
	mpv.mpv_cmd({ "add", "volume", 5 })
end

function M.decrease_volume()
	mpv.mpv_cmd({ "add", "volume", -5 })
end

function M.download_song()
	vim.ui.input({ prompt = "Youtube video url: " }, function(url)
		if not url then
			vim.print("Cancelled")
			return
		end

		if url == "" then
			vim.print("Cancelled")
			return
		end

		local is_valid = url:match("^https?://")

		if not is_valid then
			vim.notify("Invalid URL", vim.log.levels.ERROR)
			return
		end

		vim.ui.select({ "mp3", "m4a", "opus", "flac" }, {
			prompt = "Select audio format:",
		}, function(format)
			if not format then
				vim.print("Cancelled")
				return
			end

			if format == "" then
				vim.print("Cancelled")
				return
			end

			vim.ui.select({ "128k", "192k", "256k", "320k" }, {
				prompt = "Select quality:",
			}, function(quality)
				if not quality then
					vim.print("Cancelled")
					return
				end

				if quality == "" then
					vim.print("Cancelled")
					return
				end

				vim.ui.input({ prompt = "Name (optional): " }, function(name)
					if not name then
						vim.print("Cancelled")
						return
					end

					local cmd = build_cmd(url, { format = format, quality = quality, name = name })

					local stderr_lines = {}

					-- call yt-dlp to download music
					vim.fn.jobstart(cmd, {
						-- display download progress
						on_stdout = function(_, data, _)
							for _, line in ipairs(data) do
								if line:match("%[download%]") then
									vim.schedule(function()
										vim.notify(line, vim.log.levels.INFO)
									end)
								end
							end
						end,
						on_exit = function(_, exit_code, _)
							-- download failed
							if exit_code ~= 0 then
								vim.schedule(function()
									vim.notify(
										"Download failed:\n" .. table.concat(stderr_lines, "\n"),
										vim.log.levels.ERROR
									)
								end)
							else
								vim.schedule(function()
									insert_new_song(files)
									vim.notify("Download completed!")
								end)
							end
						end,
						on_stderr = function(_, data, _)
							for _, line in ipairs(data) do
								if line ~= "" then
									table.insert(stderr_lines, line)
								end
							end
						end,
					})
				end)
			end)
		end)
	end)
end

function M.delete_song(file)
	local function remove_from_playlist(index, fullpath, song)
		mpv.mpv_cmd({ "playlist-remove", index }, function()
			vim.schedule(function()
				local ok, err = pcall(vim.fs.rm, fullpath)

				if ok then
					vim.notify("Deleted: " .. song.filename)
				else
					vim.notify("Failed to delete the file: " .. ", err: " .. err)
				end
			end)
		end)
	end

	-- confirmation
	vim.ui.select({ "No", "Yes" }, { prompt = "Delete " .. file .. "?" }, function(result)
		if not result or result == "No" then
			return
		end

		local song = get_song_file(file)

		if not song then
			vim.notify("Song not found", vim.log.levels.WARN)
			return
		end

		local fullpath = constants.MUSIC_PATH .. "/" .. song.full_name

		mpv.mpv_cmd({ "get_property", "playlist" }, function(playlist)
			local mpv_index = nil

			for i, item in ipairs(playlist) do
				if item.id == song.mpv_id then
					mpv_index = i - 1 -- 0-based
					break
				end
			end

			remove_from_playlist(mpv_index, fullpath, song)
		end)
	end)
end

function M.switch_mode(cb)
	local current_mode = local_state.load_mode()
	local new_mode = next_mode(current_mode)

	if new_mode == "normal" then
		mpv.mpv_cmd({ "set_property", "loop-file", "no" }, function()
			mpv.mpv_cmd({ "playlist-unshuffle" }, function()
				if cb then
					cb(new_mode)
				end
			end)
		end)
	elseif new_mode == "loop" then
		mpv.mpv_cmd({ "set_property", "loop-file", "inf" }, function()
			if cb then
				cb(new_mode)
			end
		end)
	elseif new_mode == "random" then
		mpv.mpv_cmd({ "set_property", "loop-file", "no" }, function()
			mpv.mpv_cmd({ "playlist-shuffle" }, function()
				if cb then
					cb(new_mode)
				end
			end)
		end)
	end
end

function M.sync_mpv_ids()
	mpv.mpv_cmd({ "get_property", "playlist" }, function(playlist)
		if not playlist then
			return
		end

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
	M.update_files()
end

M.get_files = get_files
M.sync_playlist = sync_playlist

return M
