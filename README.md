# yt-playlist.nvim

> 🎵 A Neovim plugin to browse, download, and play YouTube playlists — without leaving your editor.

---

## Features

- **Download songs** directly from YouTube
- **Play / Pause** with a single keymap
- **Previous / Next** track navigation
- **Rewind / Forward** through the current song
- **Play modes** — switch between `Normal`, `Loop`, and `Random`
- **Remove songs** from your playlist
- **Volume control** on the fly

---

## Prerequisites

Before installing, make sure you have the following tools available on your system:

- [**mpv**](https://mpv.io/) — media player used for audio playback
- [**yt-dlp**](https://github.com/yt-dlp/yt-dlp) — used to download and stream YouTube content

> [!WARNING]
> **yt-playlist.nvim only supports macOS and Linux.**
> Windows is not currently supported.

### Installing prerequisites

**macOS (Homebrew):**
```bash
brew install mpv yt-dlp
```

**Linux (apt):**
```bash
sudo apt install mpv
pip install yt-dlp
```

**Linux (pacman):**
```bash
sudo pacman -S mpv yt-dlp
```

---

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "666RED/yt-playlist.nvim",
  config = function()
    require("yt-playlist").setup()
  end,
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "666RED/yt-playlist.nvim",
  config = function()
    require("yt-playlist").setup()
  end
}
```

---

## Configuration

```lua
require("yt-playlist").setup({
  -- your config options here
})
```

---

## Usage

### Command
| Command | Action |
|-|-|
| YtPlayList | Open playlist |
| PlayPause | Play / pause current song |

### Keymaps

| Key | Action |
|-|--|
| `<M-p>` | Play / Pause |
| `<M-j>` | Next song |
| `<M-k>` | Previous song |
| `<M-l>` | Forward |
| `<M-h>` | Rewind |
| `<M-m>` | Switch play mode (Normal → Loop → Random) |
| `<M-d>` | Download song |
| `<M-x>` | Remove song from playlist |
| `=` | Volume up |
| `-` | Volume down |

### Play Modes

| Mode | Description |
|------|-------------|
| `Normal` | Play through the playlist in order |
| `Loop` | Repeat the same song infinitely |
| `Random` | Shuffle and play randomly |

---

## Roadmap

- [ ] Rename songs in the playlist
- [ ] Add songs to custom playlists

---

## Contributing

Contributions, issues, and feature requests are welcome!
Feel free to open an [issue](https://github.com/666RED/yt-playlist.nvim/issues) or submit a pull request.

---

## License

MIT © [666RED](https://github.com/666RED)

