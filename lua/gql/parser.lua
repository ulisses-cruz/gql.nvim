local has_ts_utils, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
if not has_ts_utils then
    error 'Treesitter not found'
end

local lang = 'graphql'
local parser = {}
local ignored_nodes = {
    'comment',
    'source',
    'source_file',
    'document',
}

function parser.parse_cursor_position()
    local bufnr = vim.fn.bufnr()
    local original_cursor_pos = vim.fn.line '.'
    local query = parser.get_query(bufnr)
    local metadata = parser.get_metadata(bufnr)
    vim.call('cursor', original_cursor_pos, 0)
    return vim.tbl_extend('force', query, metadata)
end

function parser.get_query(bufnr)
    local node = parser.find_query_node()
    local operation_name = parser.get_operation_name(node, bufnr)
    local text = vim.treesitter.query.get_node_text(node, bufnr)
    text = string.gsub(text, '\n', '')
    return { query = text, operation_name = operation_name }
end

function parser.find_query_node()
    local node = parser.ignore_non_query_node()
    return parser.get_root_of_node(node)
end

function parser.get_root_of_node(node)
    local parent = node:parent()
    while parent ~= nil and parent:type() ~= 'definition' do
        node = parent
        parent = node:parent()
    end
    return node
end

function parser.ignore_non_query_node()
    local current_line = vim.fn.line '.'
    local last_line = vim.fn.line '$'

    local node = nil
    while current_line <= last_line do
        node = ts_utils.get_node_at_cursor()
        if not node or not vim.tbl_contains(ignored_nodes, node:type()) then
            break
        end
        current_line = parser.move_cursor 'down'
    end
    assert(node, 'No query found. Make sure you have the graphql parser installed and your cursor is on the query.')
    return node
end

function parser.move_cursor(dir)
    local current_line = vim.fn.line '.'
    if dir == 'up' then
        current_line = current_line - 1
        vim.call('cursor', current_line, 0)
    elseif dir == 'down' then
        current_line = current_line + 1
        vim.call('cursor', current_line, 0)
    end
    return current_line
end

function parser.get_metadata(bufnr)
    local text = parser.get_metadata_text(bufnr)
    local endpoint = parser.get_endpoint(text, bufnr)
    local variables = parser.get_variables(text)
    return { endpoint = endpoint, variables = variables }
end

function parser.get_metadata_text(bufnr)
    local last = parser.put_cursor_above_query()
    local first = last
    while first > 0 do
        local node = ts_utils.get_node_at_cursor()
        if not node or not vim.tbl_contains(ignored_nodes, node:type()) then
            break
        end
        first = parser.move_cursor 'up'
    end
    if first == last then
        return nil
    else
        first = first - 1
    end
    local lines = vim.api.nvim_buf_get_lines(bufnr, first, last, false)

    if vim.tbl_isempty(lines) then
        return nil
    end
    return table.concat(lines, '\n')
end

function parser.put_cursor_above_query()
    local line = parser.move_cursor 'up'
    local node = ts_utils.get_node_at_cursor()
    while node and not vim.tbl_contains(ignored_nodes, node:type()) and line > 1 do
        line = parser.move_cursor 'up'
        node = ts_utils.get_node_at_cursor()
    end
    return line
end

function parser.get_endpoint(text, bufnr)
    local pattern = '#%s*endpoint%s*:%s*([%S]+)'
    local endpoint = nil
    if text then
        endpoint = string.match(text, pattern)
    end
    if not endpoint then
        local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        endpoint = string.match(first_line, pattern)
    end
    return endpoint
end

function parser.get_variables(text)
    if not text then
        return nil
    end
    local vtext = string.match(text, '#%s*variables%s*:%s*({.*})')
    if not vtext then
        return nil
    end
    local tjson = string.gsub(vtext, '\n#', '')
    local vars = vim.fn.json_decode(tjson)
    return vars
end

function parser.get_operation_name(node, bufnr)
    local query = vim.treesitter.parse_query(lang, '(operation_definition (name) @name)')
    for _, n, _ in query:iter_captures(node, bufnr, node:start(), node:end_()) do
        return vim.treesitter.get_node_text(n, bufnr)
    end
end

return parser
