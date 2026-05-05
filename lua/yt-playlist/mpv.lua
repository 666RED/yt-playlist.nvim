---@class MpvModule
---@field mpv_cmd fun(cmd: (string|integer|boolean)[], cb?: function): nil
---@field ensure_mpv fun(cb: function): nil
local M = {}

local function spawn_mpv()
	os.remove("/tmp/mpv.sock")

	vim.system({
		"mpv",
		"--idle",
		"--no-terminal",
		"--input-ipc-server=/tmp/mpv.sock",
		"--loop-playlist=inf",
		"--shuffle=no",
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
			end, 100)
		end)
	end

	try(20)
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

M.mpv_cmd = mpv_cmd

return M
