local M = {}

M.warn = function(msg)
    msg = vim.fn.escape(msg, '"'):gsub('\\n', '\n')
    -- vim.cmd(string.format('echohl WarningMsg | echo "Pytrize Warning: %s" | echohl None', msg))
    vim.notify(string.format("Pytrize Warning: %s", msg), vim.log.levels.WARN)
end

M.err = function(msg)
    msg = vim.fn.escape(msg, '"'):gsub('\\n', '\n')
    vim.notify(string.format("Pytrize Error: %s", msg), vim.log.levels.ERROR)
end

return M
