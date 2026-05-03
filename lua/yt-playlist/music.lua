---@class MusicModule
---@field get_files fun(): Song_File[]
---@field update_files fun(): nil
---@field play_song fun(file: string, cb: fun(info: Song_Info)): nil
---@field add_to_playlist fun(file: string): nil
---@field pause_or_resume fun(): nil
---@field next_song fun(): nil
---@field prev_song fun(): nil
---@field stop fun(): nil
---@field increase_volume fun(): nil
---@field decrease_volume fun(): nil
---@field sync_playlist fun(cb?: function): nil
---@field get_current_song fun(cb: fun(info: Song_Info): nil): nil
---@field download_song fun(): nil
---@field delete_song fun(song: string, cb: function): nil
local M = {}

---@type Song_File[]
local files = {}

-- note: MODULES

---@type MpvModule
local mpv = require("yt-playlist.mpv")

---@type UtilModule
local util = require("yt-playlist.util")

local constants = require("yt-playlist.constants")

-- note: LOCAL FUNCTIONS

local function get_files()
	return files
end

local function sync_playlist(cb)
	-- clear the playlist, empty / left playing song
	mpv.mpv_cmd({ "playlist-clear" }, function()
		mpv.mpv_cmd({ "get_property", "media-title" }, function(current)
			local current_song_position = nil

			if not current then
				for _, file in ipairs(files) do
					local fullpath = constants.MUSIC_PATH .. "/" .. file.full_name

					mpv.mpv_cmd({ "loadfile", fullpath, "append" })
				end
			else
				for index, file in ipairs(files) do
					local fullpath = constants.MUSIC_PATH .. "/" .. file.full_name
					local current_path = constants.MUSIC_PATH .. "/" .. current

					if fullpath ~= current_path then
						mpv.mpv_cmd({ "loadfile", fullpath, "append" })
					else
						current_song_position = index
					end
				end

				-- move current song to the correct position (if any)
				mpv.mpv_cmd({ "playlist-move", 0, current_song_position })
			end

			if cb then
				cb()
			end
		end)
	end)
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

local function update_files()
	files = {}
	local all_files = get_all_files()

	for _, file in ipairs(all_files) do
		table.insert(files, util.get_song_file(file))
	end
end

local function get_current_song(cb)
	local info = {}
	local pending = 4

	local function done()
		pending = pending - 1

		if pending <= 0 then
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
	update_files()

	for i = 1, #files, 1 do
		-- new song found
		if not original_files[i] or original_files[i].full_name ~= files[i].full_name then
			mpv.mpv_cmd({ "loadfile", constants.MUSIC_PATH .. "/" .. files[i].full_name, "insert-at", i - 1 })
			break
		end
	end
end

---@param file string
---@return Song_File_With_Index
local function get_song_file(file)
	for i, song in ipairs(files) do
		if song.filename == file then
			---@type Song_File_With_Index
			local result = vim.tbl_extend("force", song, { index = i })
			return result
		end
	end

	return {}
end

-- note: EXPORT FUNCTIONS

function M.play_song(file, cb)
	local song = get_song_file(file)

	local function play_current_song()
		mpv.mpv_cmd({ "set_property", "playlist-pos", song.index - 1 }, function()
			vim.defer_fn(function()
				get_current_song(function(data)
					cb(data)
				end)
			end, 1000)
		end)
	end

	-- check if files and playlist are synced
	mpv.mpv_cmd({ "get_property", "playlist" }, function(playlist)
		if not playlist then
			sync_playlist(play_current_song)
			return
		end

		local item = playlist[song.index]

		if not item or item.filename ~= constants.MUSIC_PATH .. "/" .. song.full_name then
			sync_playlist(play_current_song)
			return
		end

		play_current_song()
	end)
end

function M.add_to_playlist(file)
	mpv.mpv_cmd({ "loadfile", file, "append" })
end

function M.pause_or_resume()
	mpv.mpv_cmd({ "cycle", "pause" })
end

function M.next_song()
	mpv.mpv_cmd({ "playlist-next" })
end

function M.prev_song()
	mpv.mpv_cmd({ "playlist-prev" })
end

function M.stop()
	mpv.mpv_cmd({ "stop" })
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
						on_exit = function()
							insert_new_song(files)
							vim.notify("Download completed!")
						end,
					})
				end)
			end)
		end)
	end)
end

function M.delete_song(file, cb)
	-- confirmation
	vim.ui.select({ "No", "Yes" }, { prompt = "Delete " .. file .. "?" }, function(result)
		if result == "No" then
			return
		end

		local song = get_song_file(file)

		if not song then
			vim.notify("Song not found", vim.log.levels.WARN)
			return
		end

		local fullpath = constants.MUSIC_PATH .. "/" .. song.full_name

		mpv.mpv_cmd({ "playlist-remove", song.index - 1 }, function()
			vim.schedule(function()
				local ok, err = pcall(vim.fs.rm, fullpath)

				if ok then
					vim.notify("Deleted: " .. song.filename)
					cb()
				else
					vim.notify("Failed to delete: " .. song.filename .. ", err: " .. err)
				end
			end)
		end)
	end)
end

function M.setup()
	update_files()
end

M.get_current_song = get_current_song
M.get_files = get_files
M.sync_playlist = sync_playlist
M.update_files = update_files

return M
