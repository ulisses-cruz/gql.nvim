local utils = require 'gql.utils'

local client = {}
local default_endpoint = 'http://localhost:3000/'

function client.send_request(data)
    local url = client.request_url(data)
    if not url then
        return
    end
    data = client.prepare_data(data)

    client.curl(url, data)
end

function client.prepare_data(data)
    return vim.fn.json_encode {
        operationName = data.operation_name,
        query = data.query,
        variables = data.variables,
    }
end

function client.request_url(data)
    if data.endpoint == nil then
        data.endpoint = vim.fn.input('Endpoint: ', default_endpoint)
    end
    return data.endpoint
end

client.curl = function(url, data)
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
        on_stdout = function(_, response)
            utils.display(response)
        end,
        on_stderr = function(_, response)
            utils.display(response)
        end,
    })
end

return client
