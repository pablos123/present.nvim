local H = {}

function H.make_win_minimal(winnr)
    if winnr == -1 then return end
    local function set_win_option(opt, value)
        vim.api.nvim_set_option_value(opt, value, { win = winnr })
    end
    set_win_option('number', false)
    set_win_option('relativenumber', false)
    set_win_option('cursorline', false)
    set_win_option('foldcolumn', '0')
    set_win_option('signcolumn', 'no')
    set_win_option('colorcolumn', '')
    set_win_option('spell', false)
    set_win_option('list', false)
end

function H.make_buf_modifiable(bufnr, modifiable)
    local function set_buf_option(opt, value)
        vim.api.nvim_set_option_value(opt, value, { buf = bufnr })
    end

    if modifiable then
        set_buf_option('readonly', false)
        set_buf_option('modifiable', true)
    else
        set_buf_option('readonly', true)
        set_buf_option('modifiable', false)
    end
end

function H.center_string(str)
    local ui = vim.api.nvim_list_uis()[1]
    local range_end = math.floor((ui.width - string.len(str)) * 0.5)
    for _ = 0, range_end do str = ' ' .. str end
    return str
end

function H.file_exists(filepath)
    local stat = vim.loop.fs_stat(filepath)
    return stat ~= nil and stat.type == 'file'
end

local PresentClass = {}

function PresentClass:next_slide()
    if vim.api.nvim_get_current_buf() ~= self.slides_buf then
        print("You are not in the slides' buffer.")
        return
    end

    local counter = self.counter + 1
    if counter == self.files_count + 1 then counter = 1 end

    local file_path = self.files[counter]
    if not H.file_exists(file_path) then
        print('Next slide removed or missing. Start a new presentation.')
        return
    end

    self.counter = counter
    self:show_slide()
end

function PresentClass:previous_slide()
    if vim.api.nvim_get_current_buf() ~= self.slides_buf then
        print("You are not in the slides' buffer.")
        return
    end

    local counter = self.counter - 1
    if counter == 0 then counter = self.files_count end

    local file_path = self.files[counter]
    if not H.file_exists(file_path) then
        print('Previous slide removed or missing. Start a new presentation.')
        return
    end

    self.counter = counter
    self:show_slide()
end

function PresentClass:show_slide()
    H.make_buf_modifiable(self.slides_buf, true)
    vim.api.nvim_buf_set_lines(self.slides_buf, 0, -1, false,
        vim.fn.readfile(self.files[self.counter]))
    H.make_buf_modifiable(self.slides_buf, false)
    vim.api.nvim_set_current_buf(self.slides_buf)
    self:update_statusline()
end

function PresentClass:update_statusline()
    local statuline_str = H.center_string(self.counter .. '/' .. self.files_count)
    vim.api.nvim_buf_call(self.presentation_buf, function()
        vim.cmd('let &l:statusline="' .. statuline_str .. '"')
    end)
end

function PresentClass:prepare_files()
    local buffer_path = vim.fn.expand('%:p')

    if not H.file_exists(buffer_path) then
        print('The presentation needs to be run inside a file.')
        return false
    end

    buffer_path = vim.fn.expand('%:p:h')

    self.files = vim.split(vim.fn.glob(buffer_path .. '/*.md'), '\n', { trimempty = true })

    for i, v in ipairs(self.files) do
        -- Clean directories inside files list
        if vim.fn.isdirectory(v) == 1 then table.remove(self.files, i) end
    end

    local count = 0
    for _, _ in ipairs(self.files) do count = count + 1 end

    if count == 0 then
        print('No markdown files inside the directory.')
        return false
    end

    self.files_count = count
    return true
end

function PresentClass:wipe_current_presentation()
    -- Try to move to the presentation tab
    pcall(vim.api.nvim_set_current_tabpage, self.presentation_tab)

    -- If the the presentation tab is there
    if vim.api.nvim_get_current_tabpage() == self.presentation_tab then
        -- If it's the only tab available
        if #vim.api.nvim_list_tabpages() == 1 then
            -- Create a new dummy tab
            vim.cmd('tabnew')
        end
        -- Move again to the presentation tab or remain there
        pcall(vim.api.nvim_set_current_tabpage, self.presentation_tab)
        -- Close it
        vim.cmd('tabclose')
    end

    pcall(vim.api.nvim_buf_delete, self.presentation_buf, { force = true })
    pcall(vim.api.nvim_buf_delete, self.slides_buf, { force = true })

    self.presentation_tab = nil
    self.presentation_buf = nil
    self.slides_buf = nil
end

function PresentClass:start()
    if not self:prepare_files() then return end

    self:wipe_current_presentation()

    self.presentation_buf_name = 'PRESENTATION'
    self.slide_buf_name = 'SLIDES'
    self.counter = 1

    -- Open a tab and disable cmdline
    vim.cmd('tabnew')
    vim.opt_local.cmdheight = 0

    -- Create the presentation buffer
    self.presentation_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(self.presentation_buf, self.presentation_buf_name)

    -- Make the window visible. Move to the new buffer
    vim.api.nvim_set_current_buf(self.presentation_buf)

    -- Make it full screen
    vim.api.nvim_buf_call(self.presentation_buf, function()
        vim.cmd('resize | vertical resize')
    end)

    -- Get the id of the new created tab
    self.presentation_tab = vim.api.nvim_get_current_tabpage()

    -- Configure the window and buffer
    H.make_win_minimal(vim.fn.bufwinid(self.presentation_buf))
    H.make_buf_modifiable(self.presentation_buf, false)
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = self.presentation_buf })
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = self.presentation_buf })

    local ui = vim.api.nvim_list_uis()[1]
    local total_width = ui.width
    local total_height = ui.height
    local float_width = math.floor(total_width * 0.75)
    local float_height = math.floor(total_height * 0.75)

    -- Create the slides window
    self.slides_win = vim.api.nvim_open_win(self.presentation_buf, true, {
        relative = 'editor',
        style = 'minimal',
        col = math.floor((total_width - float_width) * 0.5),
        row = math.floor((total_height - float_height) * 0.5),
        width = float_width,
        height = float_height,
    })

    H.make_win_minimal(self.slides_win)

    -- Create the slides buffer
    self.slides_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(self.slides_buf, self.slide_buf_name)

    -- One time only settings
    vim.api.nvim_set_option_value('wrap', true, { win = self.slides_win })
    vim.api.nvim_set_option_value('filetype', 'markdown', { buf = self.slides_buf })
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = self.slides_buf })

    -- Create mappings
    vim.keymap.set('n', 'gn', function() self:next_slide() end, { buffer = self.slides_buf, silent = true })
    vim.keymap.set('n', 'gp', function() self:previous_slide() end, { buffer = self.slides_buf, silent = true })

    self:show_slide()
end

local Present = {}

function Present.setup() _G.Present = Present end

function Present.start() PresentClass:start() end

function Present.stop() PresentClass:wipe_current_presentation() end

function Present.next_slide() PresentClass:next_slide() end

function Present.previous_slide() PresentClass:previous_slide() end

return Present
