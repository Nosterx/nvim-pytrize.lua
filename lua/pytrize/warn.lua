local M = {}

M.warn = function(msg)
    msg = vim.fn.escape(msg, '"'):gsub('\\n', '\n')
    -- vim.cmd(string.format('echohl WarningMsg | echo "Pytrize Warning: %s" | echohl None', msg))
    vim.notify(string.format("Pytrize Warning: %s", msg), vim.log.levels.WARN)
end

return M
