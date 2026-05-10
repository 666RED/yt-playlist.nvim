local M = {}

-- note: MODULES

---@type AsyncModule
local async = require("yt-playlist.async")

function M.setup(buf)
	local actions = require("yt-playlist.command_config").setup()

	local mappings = {
		p = actions.PlayPause,
		k = actions.PrevSong,
		j = actions.NextSong,
		h = actions.SkipBack,
		l = actions.SkipForward,
		d = actions.Download,
		m = actions.SwitchMode,
		["-"] = actions.DecreaseVolume,
		["="] = actions.IncreaseVolume,
		s = actions.SwitchPlaylist,
		a = actions.AddPlaylist,
	}

	vim.api.nvim_buf_set_keymap(buf, "n", "<M-x>", "", {
		callback = function()
			async.sync(function()
				local current_line = vim.api.nvim_get_current_line()
				async.wait(actions.Delete(current_line))
			end)()
		end,
	})

	local keymap = nil

	for key, fn in pairs(mappings) do
		if key == "-" or key == "=" then
			keymap = key
		else
			keymap = "<M-" .. key .. ">"
		end

		vim.api.nvim_buf_set_keymap(buf, "n", keymap, "", {
			callback = function()
				async.sync(function()
					async.wait(fn())
				end)()
			end,
		})
	end
end

return M
