# Neovim UI fundamentals
- api_floatwin
- nvim_open_win
- buffer_options

# Key handling strategy
- buffer-local mappings
- nvim_buf_set_keymap
- map-local

# Async + job control
- playback + updates
- jobstart
- timer_start

# State management
- How to track
    - current playlist
    - current index
    - playback state (playing / paused)
    - shuffle mode

# File scanning
- scan directory -> filter .m4a files
- vim.loop (libuv) / vim.fn.glob

# Rendering strategy
- How often to update UI (song timestamp)
- Avoid excessive redraws

# UX decisions
- Disable multiple players
- What happen if user closes the window?
- Should music continue in background

# Mental model
- Buffer = selection UI
- Floating window = status / control panel
- External player = actual audio engine

## Example Floating window UI
```
Now Playing: song_name.m4a
Time: 01:23 / 03:45

[p] Play/Pause   [n] Next   [b] Prev
[s] Shuffle      [q] Close
```
