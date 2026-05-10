---@class ControllerModule
---@field start_mpv_listener fun(): uv.uv_pipe_t| nil
local M = {}

-- note: MODULES

---@type AsyncModule
local async = require("yt-playlist.async")

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

---@type CommonModule
local common = require("yt-playlist.common")

---@type UiModule
local ui = require("yt-playlist.ui")

---@type MusicModule
local music = require("yt-playlist.music")

local function send(handle, cmd)
	handle:write(vim.json.encode(cmd) .. "\n")
end

function M.start_mpv_listener()
	local handle = vim.loop.new_pipe(false)
	local playlist_timer = vim.uv.new_timer()

	if not handle then
		-- todo: may handle this
		return nil
	end

	handle:connect("/tmp/mpv.sock", function(err)
		if err then
			return
		end

		-- send observe_property command
		send(handle, { command = { "observe_property", 1, "playlist-pos" } })
		send(handle, { command = { "observe_property", 2, "volume" } })
		send(handle, { command = { "observe_property", 3, "pause" } })
		-- send(handle, { command = { "observe_property", 4, "time-pos" } })

		-- listen for incoming events
		handle:read_start(function(read_err, data)
			if read_err or not data then
				return
			end

			-- split events by new line
			for line in data:gmatch("[^\n]+") do
				if line ~= "" then
					local ok, event = pcall(vim.json.decode, line)

					if not ok then
						return
					end

					-- note: update volume buf when volume is adjusted
					if event.event == "property-change" and event.name == "volume" then
						common.update_player_state({ volume = event.data })
						ui.update_volume_buf()
					end

					-- note: update playlist and info when song position is updated
					if event.event == "property-change" and event.name == "playlist-pos" then
						if playlist_timer then
							playlist_timer:stop()

							playlist_timer:start(
								100,
								0,
								vim.schedule_wrap(function()
									async.sync(function()
										local info = async.wait(music.get_current_song())
										common.update_player_state(info)

										ui.update_info_buf()
										async.wait(ui.update_playlist_buf())

										if global_state.player_state and global_state.player_state.title then
											vim.schedule(function()
												vim.notify("Now playing: " .. global_state.player_state.title)
											end)
										end
									end)()
								end)
							)
						end
					end

					-- note: update info buf when rewind / forward
					if event.event == "seek" then
						async.sync(function()
							local info = async.wait(music.get_current_song())
							common.update_player_state(info)

							ui.update_info_buf()
						end)()
					end
				end
			end
		end)
	end)
	return handle
end
return M
