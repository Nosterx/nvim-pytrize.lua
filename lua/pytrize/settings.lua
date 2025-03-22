local M = {}

local notify = require('pytrize.notify')

-- defaults
M.settings = {
    no_commands = false,
    no_autocmds = false,
    highlight = 'LineNr',
    preferred_input = 'telescope',
}

M.update = function(opts)
    for k, v in pairs(opts) do
        if M.settings[k] == nil then
            notify.warn("unexpected setting " .. k)
        else
            M.settings[k] = v
        end
    end
end

return M
