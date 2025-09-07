local M = {}

function M.urlencode_path(p)
    return (
        p:gsub("[^%w%._%-%/~]", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
    )
end

return M
