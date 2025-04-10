local M = {}

M.check = function()
    vim.health.start('present.nvim')
    if vim.fn.has('nvim-0.10') == 1 then
        vim.health.ok('nvim >= 0.10')
    else
        vim.health.error('nvim version is below 0.10')
    end
end

return M
