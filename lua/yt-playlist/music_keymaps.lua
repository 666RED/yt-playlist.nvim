local M = {}

function M.setup(buf)
	local actions = require("yt-playlist.command_config").setup()

	local mappings = {
		p = actions.PlayPause,
		k = actions.PrevSong,
		j = actions.NextSong,
		h = actions.SkipBack,
		l = actions.SkipForward,
		d = actions.Download,
		s = actions.Shuffle,
		x = actions.Delete,
	}

	for key, fn in pairs(mappings) do
		vim.api.nvim_buf_set_keymap(buf, "n", "<M-" .. key .. ">", "", {
			callback = function()
				local current_line = vim.api.nvim_get_current_line()
				fn(current_line)
			end,
		})
	end
end

return M
