local M = {}

local Job = require('plenary.job')
local Path = require('plenary.path')

local notify = require('pytrize.notify')
local open_file = require('pytrize.jump.util').open_file

local conf = require('telescope.config').values
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local function normal(cmd)
    vim.cmd(string.format('normal! %s', cmd))
end

local function get_word_under_cursor()
    local savereg = vim.fn.getreginfo('"')
    normal('yiw')
    local word = vim.fn.getreg('"')
    vim.fn.setreg('"', savereg)
    return word
end

local function parse_raw_fixture_output(cwd, lines)
    local fixtures = setmetatable({}, M.meta_nested_sized())
    local pattern = '^([%w_]*) .*%-%- (%S*):(%d*)$'
    for _, line in ipairs(lines) do
        local i, _, fixture, file, linenr = string.find(line, pattern)
        if i ~= nil then
            file = cwd / file
            linenr = tonumber(linenr)
            fixtures[fixture][file:normalize()] = linenr
        end
    end
    return fixtures
end

local function get_cwd()
    return Path:new(vim.fn.getcwd())
end

local function lookup_fixtures(callback)
    local cwd = get_cwd()
    local current_file_path = Path.new(vim.fn.expand("%:p"))
    return Job:new({
        command = 'pytest',
        args = {'--fixtures', '-v', current_file_path},
        cwd = vim.fn.getcwd(),
        on_exit = vim.schedule_wrap(function(j, return_val)
            if return_val == 0 then
                local fixtures = parse_raw_fixture_output(cwd, j:result())
                callback(fixtures)
            else
                notify.err(
                    string.format(
                        'failed to query fixtures, pytest response code: %d, result: %s',
                        return_val,
                        table.concat(j:result(), '\n')
                    )
                )
            end
        end),
    })
end

M.meta_nested_sized = function ()
    return {
        __index = function (self1, key1)
            local new_entry = {}
            rawset(self1, key1, new_entry)
            return new_entry
        end,
    }
end

local len = function(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

M.fixtures_cache = setmetatable({}, M.meta_nested_sized())

M.fixtures_cache.update = function(opts)
    for fixture, locations in pairs(opts) do
        for file, linenr in pairs(locations) do
            M.fixtures_cache[fixture][file] = linenr
        end
    end
end

M.warm_up_cache = function()
    return lookup_fixtures(function(fixtures)
        M.fixtures_cache.update(fixtures)
    end)
end

M._to_declaration = function(fixture, file, linenr)
    open_file(tostring(file))
    vim.api.nvim_win_set_cursor(0, {linenr, 0})
    vim.fn.search(fixture)
end

M.to_declaration = function()
    local fixture = get_word_under_cursor()
    local locations = M.fixtures_cache[fixture]
    if len(locations) > 0 then
        if len(locations) == 1 then
            for file, linenr in pairs(locations) do
                M._to_declaration(fixture, file, linenr)
                return
            end
        else
            local entries = {}
            for path, linenr in pairs(locations) do
                table.insert(entries, {path = path, linenr = linenr})
            end
            pickers.new({}, {
                prompt_title = 'Ambiguous fixture name, please choose a file',
                finder = finders.new_table {
                    results = entries,
                    entry_maker = function(entry)
                        return {
                            path = entry.path,
                            linenr = entry.linenr,
                            value = tostring(entry.path),
                            display = entry.path .. ':' .. entry.linenr,
                            ordinal = entry.path .. ':' .. entry.linenr,
                        }
                    end,
                },
                sorter = sorters.get_generic_fuzzy_sorter(),
                attach_mappings = function(prompt_bufnr, map)
                    actions.select_default:replace(function()
                        actions.close(prompt_bufnr)
                        local selection = action_state.get_selected_entry()
                        M._to_declaration(fixture, selection.path, selection.linenr)
                    end)
                    return true
                end,
                previewer = conf.file_previewer({}),
            }):find()
            return
        end
    else
        notify.warn(string.format('fixture "%s" not found', fixture))
    end
end

return M
