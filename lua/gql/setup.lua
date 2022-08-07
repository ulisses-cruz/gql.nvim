local actions = require 'gql.actions'

local function setup(options)
    local group = 'GQLNvim'
    vim.api.nvim_create_augroup(group, {})

    vim.api.nvim_create_autocmd('FileType', {
        pattern = options.filetypes or { 'graphql' },
        group = group,
        callback = function(o)
            for k, v in pairs(options.keymaps) do
                vim.keymap.set('n', v, function()
                    actions[k]()
                end, { buffer = o.buf, silent = true })
            end
        end,
    })
end

return setup
