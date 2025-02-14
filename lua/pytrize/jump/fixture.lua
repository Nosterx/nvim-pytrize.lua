local M = {}

local Job = require('plenary.job')
local Path = require('plenary.path')

local warn = require('pytrize.warn').warn
local open_file = require('pytrize.jump.util').open_file

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
    local fixtures = {}
    local pattern = '^([%w_]*) .*%-%- (%S*):(%d*)$'
    for _, line in ipairs(lines) do
        local i, _, fixture, file, linenr = string.find(line, pattern)
        if i ~= nil then
            fixtures[fixture] = {
                file = cwd / file,
                linenr = tonumber(linenr),
            }
        end
    end
    return fixtures
end

local function get_cwd()
    return Path:new(vim.api.nvim_buf_get_name(0)):parent()
end

local function lookup_fixtures(callback)
    local cwd = get_cwd()
    local current_file_path = Path.new(vim.fn.expand("%:p"))
    return Job:new({
        command = 'pytest',
        args = {'--fixtures', '-v', current_file_path},
        cwd = tostring(cwd),
        on_exit = vim.schedule_wrap(function(j, return_val)
            if return_val == 0 then
                local fixtures = parse_raw_fixture_output(cwd, j:result())
                callback(fixtures)
            else
                warn(
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

M.fixtures_cache = {}

M.fixtures_cache.update = function(opts)
    for k, v in pairs(opts) do
        M.fixtures_cache[k] = v
    end
end

M.warm_up_cache = function()
    return lookup_fixtures(function(fixtures)
        M.fixtures_cache.update(fixtures)
    end)
end

M._to_declaration = function(fixture, fixture_location)
    local file = fixture_location.file
    local linenr = fixture_location.linenr
    open_file(tostring(file))
    vim.api.nvim_win_set_cursor(0, {linenr, 0})
    vim.fn.search(fixture)
end

M.to_declaration = function()
    local fixture = get_word_under_cursor()
    local fixture_location = M.fixtures_cache[fixture]
    if fixture_location ~= nil then
        M._to_declaration(fixture, fixture_location)
    else
        M.warm_up_cache():sync()
    end

    fixture_location = M.fixtures_cache[fixture]
    if fixture_location ~= nil then
        M._to_declaration(fixture, fixture_location)
    else
        warn(string.format('fixture "%s" not found', fixture))
    end
end

return M
