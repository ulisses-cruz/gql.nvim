local ok_for_ts_utils, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
if not ok_for_ts_utils then
    error 'Treesitter not found'
    return
end

local function get_buffer()
    local tmp_name = 'gql_nvim_results'
    local file_type = 'json'
    local existing_bufnr = vim.fn.bufnr(tmp_name)
    if existing_bufnr ~= -1 then
        vim.api.nvim_buf_set_option(existing_bufnr, 'modifiable', true)
        vim.api.nvim_buf_set_option(existing_bufnr, 'ft', file_type)
        vim.api.nvim_buf_set_option(existing_bufnr, 'buftype', 'nofile')
        vim.api.nvim_buf_set_lines(existing_bufnr, 0, vim.api.nvim_buf_line_count(existing_bufnr), false, {})
        return existing_bufnr
    end
    local new_bufnr = vim.api.nvim_create_buf(false, 'nomodeline')
    vim.api.nvim_buf_set_name(new_bufnr, tmp_name)
    vim.api.nvim_buf_set_option(new_bufnr, 'ft', file_type)
    vim.lsp.buf_attach_client(new_bufnr, 1)
    vim.api.nvim_buf_set_option(new_bufnr, 'buftype', 'nofile')
    return new_bufnr
end

local function show_buffer(bufnr)
    if vim.fn.bufwinnr(bufnr) == -1 then
        vim.cmd('vert sb' .. bufnr)
    else
        local winid = vim.fn.bufwinid(bufnr)
        vim.fn.win_gotoid(winid)
    end
    vim.lsp.buf.format { bufnr = bufnr }
    -- vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

local function curl(url, data)
    local bufnr = get_buffer()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    vim.fn.jobstart({
        'curl',
        url,
        '-s',
        '-X',
        'POST',
        '-H',
        'Content-Type: application/json',
        '-d',
        data,
    }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data then
                vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
                show_buffer(bufnr)
            end
        end,
        on_stderr = function(_, data)
            if data then
                vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
                show_buffer(bufnr)
            end
        end,
    })
end

local function get_query()
    local node = ts_utils.get_node_at_cursor()
    if node == nil then
        error 'No treesitter parser found'
    end

    local parent = node:parent()
    while parent ~= nil and parent:type() ~= 'definition' do
        node = parent
        parent = node:parent()
    end
    local bufnr = 0
    local query = vim.treesitter.query.get_node_text(node, bufnr)
    local start = node:start()
    return query, start + 1
end

local function get_metadata(row)
    if row == 0 then
        return nil
    end
    local end_ = row
    local start = end_
    local bufnr = vim.fn.bufnr()

    while true do
        local line = vim.api.nvim_buf_get_lines(bufnr, start - 1, start, false)[1]
        if start == 0 or (string.sub(line, 1, 1) ~= '' and string.match(line, '^#') ~= '#') then
            break
        end
        start = start - 1
    end
    if start > 0 then
        start = start + 1
    end
    local lines = vim.api.nvim_buf_get_lines(bufnr, start, end_, false)
    if vim.tbl_isempty(lines) then
        return nil
    end
    local meta = table.concat(lines, '\n')
    return meta
end

local function get_endpoint(metadata)
    local pattern = '#%s*endpoint%s*:%s*([^%s]+)'
    local endpoint = nil
    if metadata then
        endpoint = string.match(metadata, pattern)
    end
    if not endpoint then
        local bufnr = vim.fn.bufnr()
        local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        endpoint = string.match(first_line, pattern)
    end
    return endpoint
end

local function get_variables(metadata)
    if not metadata then
        return nil
    end
    local vtext = string.match(metadata, '#%s*variables%s*:%s*{(.*)}')
    if not vtext then
        return nil
    end
    local vars = {}
    for k, v in string.gmatch(vtext, '"(%w+)"%s*:%s*("?%w*"?)') do
        vars[k] = v
    end
    return vars
end

local function get_operation_name(query)
    return string.match(query, '^%a+%s*(%w+)')
end

local function make_request(endpoint, query, variables, operation_name)
    local data = ''
    if operation_name then
        data = string.format('"operationName": %q', operation_name)
    else
        data = string.format '"operationName": null'
    end

    data = string.format('%s, "query":%q', data, string.gsub(query, '\n', ''))

    if variables then
        local vars = {}
        for k, v in pairs(variables) do
            table.insert(vars, string.format('%q:%s', k, v))
        end
        vars = table.concat(vars, ', ')
        data = string.format('%s, "variables": { %s }', data, vars)
    else
        data = string.format('%s, "variables": null', data)
    end
    data = string.format('{%s}', data)

    if endpoint == nil then
        endpoint = vim.fn.input('Endpoint: ', 'http://localhost:3000/')
    end

    curl(endpoint, data)
end

local M = {}

M.actions = {
    run = function()
        local query, query_start = get_query()
        local operation_name = get_operation_name(query)
        local metadata = get_metadata(query_start - 1)
        local endpoint = get_endpoint(metadata)
        local variables = get_variables(metadata)
        make_request(endpoint, query, variables, operation_name)
    end,
}

M.setup = function(options)
    local group = 'GQLNvim'
    vim.api.nvim_create_augroup(group, {})

    vim.api.nvim_create_autocmd('FileType', {
        pattern = options.FileTypes or { 'graphql' },
        group = group,
        callback = function(o)
            for k, v in pairs(options.keymaps) do
                vim.keymap.set('n', v, function()
                    M.actions[k]()
                end, { buffer = o.buf, silent = true })
            end
        end,
    })
end

return M
