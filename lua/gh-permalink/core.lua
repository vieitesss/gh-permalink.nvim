local M = {}

function M.urlencode_path(p)
    return (
        p:gsub("[^%w%._%-%/~]", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
    )
end

function M.relpath(abs, root)
    local uv = vim.uv or vim.loop

    local abs_r = (uv.fs_realpath and uv.fs_realpath(abs)) or abs

    local root_r = (uv.fs_realpath and uv.fs_realpath(root)) or root

    if not abs_r or not root_r then
        return nil
    end

    if abs_r:sub(1, #root_r) ~= root_r then
        return nil
    end

    return abs_r:sub(#root_r + 2):gsub("\\", "/")
end

function M.get_line_range_and_mode()
    local m = vim.fn.mode(1)

    if m:match("^[vV]") or m == "\022" then
        local lstart = vim.fn.getpos("v")[2]

        local lend = vim.fn.getpos(".")[2]

        if lstart > lend then
            lstart, lend = lend, lstart
        end

        return true, lstart, lend
    else
        local l = vim.api.nvim_win_get_cursor(0)[1]

        return false, l, l
    end
end

return M
