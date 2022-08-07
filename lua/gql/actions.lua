local parser = require 'gql.parser'
local client = require 'gql.client'

local actions = {}

actions.run = function()
    local data = parser.parse_cursor_position()
    client.send_request(data)
end

return actions
