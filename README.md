# present.nvim
Simple presentations for markdown files inside Neovim.

## Features
- Opinionated.
- Really simple.
- Only one presentation at a time.
- Open a tab to iterate over the markdown files of a directory.
- Local mappings: `gn`, `gp`, go to next and go to previous slide.

## Dependencies
- `nvim >= 0.10`.

## Install
Use your favorite plugin manager!

### lazy.nvim
```lua
{
    'pablos123/present.nvim',
    config = function() require 'present-nvim'.setup {} end
}
```

## Others
Start a presentation for the parent directory of the current open file.
```vim
:lua Present.start()
```

Stop the current presentation.
```vim
:lua Present.stop()
```

Go to the next slide.
```vim
:lua Present.next_slide()
```

Go to the previous slide.
```vim
:lua Present.previous_slide()
```
