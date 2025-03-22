local M = {}

local settings = require('pytrize.settings')

local function setup_commands()
    vim.cmd('command Pytrize lua require("pytrize.api").set()')
    vim.cmd('command PytrizeClear lua require("pytrize.api").clear()')
    vim.cmd('command PytrizeJump lua require("pytrize.api").jump()')
    vim.cmd('command PytrizeJumpFixture lua require("pytrize.api").jump_fixture()')
end


local warm_up_cache = require'pytrize.jump'.warm_up_cache

local function create_autocmd()
    vim.api.nvim_create_autocmd({"BufRead", "BufWrite", "BufEnter"}, {
        pattern = "*/tests*/*.py",
        callback = function(args)
            warm_up_cache():start()
        end,
    })
end


M.setup = function(opts)
    if opts == nil then
        opts = {}
    end
    settings.update(opts)
    if not settings.settings.no_commands then
        setup_commands()
    end
    if not settings.settings.no_autocmds then
        create_autocmd()
    end
end

return M
