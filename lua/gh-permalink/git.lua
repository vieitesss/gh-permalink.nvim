local M = {}

function M.run_git(args, cwd)
    local cmd = { "git" }
    if cwd and cwd ~= "" then
        table.insert(cmd, "-C")
        table.insert(cmd, cwd)
    end

    for _, a in ipairs(args) do
        table.insert(cmd, a)
    end

    if vim.system then
        local res = vim.system(cmd, { text = true }):wait()
        if res.code ~= 0 then
            return nil, (res.stderr ~= "" and res.stderr or res.stdout)
        end

        return (res.stdout or ""):gsub("%s+$", ""), nil
    else
        local out = vim.fn.systemlist(cmd)

        if vim.v.shell_error ~= 0 then
            return nil, table.concat(out or {}, "\n")
        end

        return table.concat(out or {}, "\n"), nil
    end
end

function M.git_root(dir)
    return M.run_git({ "rev-parse", "--show-toplevel" }, dir)
end

function M.current_commit(root)
    return M.run_git({ "rev-parse", "HEAD" }, root)
end

function M.tracked_in_head(root, path_rel)
    local out = M.run_git({ "ls-files", "--error-unmatch", path_rel }, root)
    return out ~= nil
end

function M.pick_remote(root)
    local url = M.run_git({ "remote", "get-url", "--push", "origin" }, root)
    if url and url ~= "" then
        return url
    end

    local list = M.run_git({ "remote", "-v" }, root)
    if not list then
        return nil
    end

    local first_line = list:match("([^\n]+)")
    if not first_line then
        return nil
    end

    return first_line:match("^[^%s]+%s+([^%s]+)")
end

return M
