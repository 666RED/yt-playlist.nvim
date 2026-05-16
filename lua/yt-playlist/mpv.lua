---@class MpvModule
---@field ensure_mpv function
---@field mpv_cmd fun(cmd: (string|integer|boolean)[]): fun(callback: fun(): any)
---@field get_playlist fun(): AsyncThunk<table[]>
---@field clear_playlist fun(): AsyncThunk<nil>
local M = {}

-- note: MODULES

---@type AsyncModule
local async = require("yt-playlist.async")

-- note: LOCAL FUNCTIONS
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

local function wait_mpv()
	return function(callback)
		---@param n integer
		local function try(n)
			if n <= 0 then
				return callback(false)
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
					return callback(true)
				end

				-- try 20 times, 100ms between tries -> total wait = 2 seconds max
				vim.defer_fn(function()
					try(n - 1)
				end, 10)
			end)
		end

		try(20)
	end
end

-- note: EXPORT FUNCTIONS
function M.mpv_cmd(cmd)
	return function(callback)
		vim.system({ "socat", "-", "/tmp/mpv.sock" }, {
			stdin = vim.json.encode({ command = cmd }) .. "\n",
			text = true,
		}, function(res)
			if res.code ~= 0 or not res.stdout then
				return callback(nil)
			end

			local ok, data = pcall(vim.json.decode, res.stdout)

			if not ok or data.error ~= "success" then
				return callback(nil)
			end

			return callback(data.data)
		end)
	end
end

function M.ensure_mpv()
	return async.sync(function()
		local alive = async.wait(wait_mpv())

		if alive then
			return true
		end

		spawn_mpv()

		return async.wait(wait_mpv())
	end)
end

function M.clear_playlist()
	return async.sync(function()
		async.wait(M.mpv_cmd({ "stop" }))
		-- async.wait(M.mpv_cmd({ "playlist-clear" }))
	end)
end

function M.get_playlist()
	return async.sync(function()
		return async.wait(M.mpv_cmd({ "get_property", "playlist" }))
	end)
end

return M
