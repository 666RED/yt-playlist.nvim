---@class MpvModule
---@field mpv_cmd fun(cmd: (string|integer|boolean)[], cb?: function): nil
---@field ensure_mpv fun(cb: function): nil
---@field start_mpv_listener fun(callbacks: MpvListenerCallbacks): uv.uv_pipe_t| nil -- todo: change later
local M = {}

---@type GlobalStateModule
local global_state = require("yt-playlist.global-state")

local function spawn_mpv()
	os.remove("/tmp/mpv.sock")

	vim.system({
		"mpv",
		"--idle",
		"--no-terminal",
		"--input-ipc-server=/tmp/mpv.sock",
		"--loop-playlist=inf",
		"--shuffle=no",
		"--volume-max=100",
	}, { detach = true })
end

---@param cb function
local function wait_mpv(cb)
	local function try(n)
		if n <= 0 then
			return cb(false)
		end

		vim.system({
			"socat",
			"-",
			"/tmp/mpv.sock",
		}, {
			stdin = vim.json.encode({
				command = { "get_property", "mpv-version" },
			}) .. "\n",
		}, function(res)
			-- connected
			if res.code == 0 and res.stdout ~= "" then
				return cb(true)
			end

			-- try 20 times, 100ms between tries -> total wait = 2 seconds max
			vim.defer_fn(function()
				try(n - 1)
			end, 10)
		end)
	end

	try(20)
end

local function send(handle, cmd)
	handle:write(vim.json.encode(cmd) .. "\n")
end

local function mpv_cmd(cmd, cb)
	vim.system({ "socat", "-", "/tmp/mpv.sock" }, {
		stdin = vim.json.encode({ command = cmd }) .. "\n",
		text = true,
	}, function(res)
		if cb == nil then
			return
		end

		if res.code ~= 0 or not res.stdout then
			return cb(nil)
		end

		local ok, data = pcall(vim.json.decode, res.stdout)
		if not ok or data.error ~= "success" then
			return cb(nil)
		end

		cb(data.data)
	end)
end

function M.ensure_mpv(cb)
	wait_mpv(function(alive)
		if alive then
			return cb(true)
		end

		-- if failed (no mpv instance is running) -> spawn new mpv
		spawn_mpv()

		-- try again to enable ipc server
		wait_mpv(function(ok)
			cb(ok)
		end)
	end)
end

function M.start_mpv_listener(callbacks)
	local handle = vim.loop.new_pipe(false)

	if not handle then
		-- todo: check here
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

					-- update volume buf when volume is adjusted
					if event.event == "property-change" and event.name == "volume" then
						vim.schedule(function()
							callbacks.update_volume_buf({ volume = event.data })
						end)
					end

					if event.event == "property-change" and event.name == "playlist-pos" then
						vim.schedule(function()
							callbacks.update_playlist_and_info_buf()
						end)
					end

					if event.event == "seek" then
						callbacks.update_info_buf()
					end

					-- todo: change later
					-- elseif event.event == "file-loaded" then
					-- 	-- song fully loaded, safe to fetch info
					-- 	vim.schedule(function()
					-- 		music.get_current_song(function(data)
					-- 			-- update info buf
					-- 		end)
					-- 	end)
				end
			end
		end)
	end)
	return handle
end

M.mpv_cmd = mpv_cmd

return M
