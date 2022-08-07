local utils = {}

local response_buf_name = 'gql_nvim_results'
local response_buf_ft = 'json'
local response_buf_type = 'nofile'

function utils.display(response)
    local empty = vim.tbl_count(response) == 1 and string.len(response[1]) == 0
    if response and not empty then
        local bufnr = utils.get_response_buffer()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, response)
        utils.show_buffer(bufnr)
    end
end

function utils.get_response_buffer()
    local existing_bufnr = vim.fn.bufnr(response_buf_name)
    if existing_bufnr ~= -1 then
        return utils.prepare_response_buffer(existing_bufnr)
    end
    local new_bufnr = vim.api.nvim_create_buf(false, 'nomodeline')
    return utils.prepare_response_buffer(new_bufnr)
end

function utils.prepare_response_buffer(bufnr)
    vim.api.nvim_buf_set_name(bufnr, response_buf_name)
    vim.api.nvim_buf_set_option(bufnr, 'ft', response_buf_ft)
    vim.lsp.buf_attach_client(bufnr, 1)
    vim.api.nvim_buf_set_option(bufnr, 'buftype', response_buf_type)
    return bufnr
end

function utils.show_buffer(bufnr)
    if vim.fn.bufwinnr(bufnr) == -1 then
        vim.cmd('vert sb' .. bufnr)
    else
        local winid = vim.fn.bufwinid(bufnr)
        vim.fn.win_gotoid(winid)
    end
    vim.lsp.buf.format { bufnr = bufnr }
end

return utils
