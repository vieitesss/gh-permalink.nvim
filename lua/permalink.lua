local M = {}

----- helpers -----
local function run_git(args, cwd)
    local cmd = { "git" }
    if cwd and cwd ~= "" then
        table.insert(cmd, "-C"); table.insert(cmd, cwd)
    end

    for _, a in ipairs(args) do table.insert(cmd, a) end

    if vim.system then
        local res = vim.system(cmd, { text = true }):wait()
        if res.code ~= 0 then
            return nil, (res.stderr ~= "" and res.stderr or res.stdout)
        end

        return (res.stdout or ""):gsub("%s+$", ""), nil
    else
        local out = vim.fn.systemlist(cmd)

        if vim.v.shell_error ~= 0 then return nil, table.concat(out or {}, "\n") end

        return table.concat(out or {}, "\n"), nil
    end
end

local function urlencode_path(p)
    return (p:gsub("[^%w%._%-%/~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function to_https_github_base(remote)
    if not remote or remote == "" then return nil end

    remote = remote:gsub("%s+$", "")

    -- git@host:owner/repo(.git)
    local host, owner, repo = remote:match("^git@([^:]+):([^/]+)/(.+)$")
    if not host then
        -- https://host/owner/repo(.git)  OR  ssh://git@host/owner/repo(.git)
        local _, rest = remote:match("^(%a+://)(.+)$")
        if rest then
            rest = rest:gsub("^git@", "")
            host, owner, repo = rest:match("^([^/]+)/([^/]+)/(.+)$")
        end
    end

    if not (host and owner and repo) then return nil end

    repo = repo:gsub("%.git$", "")

    return string.format("https://%s/%s/%s", host, owner, repo)
end

local function git_root(dir) return run_git({ "rev-parse", "--show-toplevel" }, dir) end

local function current_commit(root) return run_git({ "rev-parse", "HEAD" }, root) end

local function relpath(abs, root)
    local uv = vim.uv or vim.loop
    local abs_r = (uv.fs_realpath and uv.fs_realpath(abs)) or abs
    local root_r = (uv.fs_realpath and uv.fs_realpath(root)) or root

    if not abs_r or not root_r then return nil end

    if abs_r:sub(1, #root_r) ~= root_r then return nil end

    return abs_r:sub(#root_r + 2):gsub("\\", "/")
end

local function tracked_in_head(root, path_rel)
    local out = run_git({ "ls-files", "--error-unmatch", path_rel }, root)

    return out ~= nil
end

local function pick_remote(root)
    local url = run_git({ "remote", "get-url", "--push", "origin" }, root)
    if url and url ~= "" then return url end

    local list = run_git({ "remote", "-v" }, root)
    if not list then return nil end

    local first_line = list:match("([^\n]+)")
    if not first_line then return nil end

    return first_line:match("^[^%s]+%s+([^%s]+)")
end

local function get_line_range_and_mode()
    local m = vim.fn.mode(1)
    if m:match("^[vV]") or m == "\022" then
        local lstart = vim.fn.getpos("v")[2]
        local lend   = vim.fn.getpos(".")[2]

        if lstart > lend then lstart, lend = lend, lstart end

        return true, lstart, lend
    else
        local l = vim.api.nvim_win_get_cursor(0)[1]

        return false, l, l
    end
end

local function notify(level, msg)
    vim.notify(msg, level, { title = "Permalink" })
end

----- public API

---Return a GitHub permalink URL for the current buffer and selection.
---@return string|nil url
---@return table|nil meta -- { path, lstart, lend, commit, base, started_in_visual }
---@return string|nil err
function M.get_url()
    local started_in_visual, lstart, lend = get_line_range_and_mode()

    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    if file == "" then return nil, nil, "Buffer has no file on disk." end

    local dir = vim.fn.fnamemodify(file, ":h")
    local root = git_root(dir)
    if not root or root == "" then return nil, nil, "Not inside a Git repository." end

    local rel = relpath(file, root)
    if not rel then return nil, nil, "Could not compute path relative to repo root." end

    local remote = pick_remote(root)
    if not remote or remote == "" then return nil, nil, "No Git remote found (e.g. origin)." end

    local base = to_https_github_base(remote)
    if not base or not base:find("github", 1, true) then
        return nil, nil, "Remote is not a GitHub host. Only GitHub/GH Enterprise are supported."
    end

    local commit = current_commit(root)
    if not commit or commit == "" then return nil, nil, "Could not determine current commit (HEAD)." end

    if not tracked_in_head(root, rel) then
        notify(vim.log.levels.WARN, "File is not tracked at HEAD. Link may 404 until committed.")
    end

    local anchor = (lstart == lend) and ("#L" .. lstart) or ("#L" .. lstart .. "-L" .. lend)
    local url = string.format("%s/blob/%s/%s%s", base, commit, urlencode_path(rel), anchor)

    return url, {
        path = rel,
        lstart = lstart,
        lend = lend,
        commit = commit,
        base = base,
        started_in_visual = started_in_visual,
    }, nil
end

---Copy permalink to clipboard (exits Visual first) and notify.
---@return string|nil url
---@return table|nil meta
---@return string|nil err
function M.yank()
    local url, meta, err = M.get_url()
    if not url or not meta then
        notify(vim.log.levels.ERROR, err or "Failed to build permalink.")

        return nil, nil, err
    end

    -- Copy to system clipboards: '+' and '*'
    vim.fn.setreg("+", url)
    pcall(vim.fn.setreg, "*", url)

    local msg = (meta.lstart == meta.lend)
        and string.format("Yanked GitHub permalink for %s:L%d", meta.path, meta.lstart)
        or string.format("Yanked GitHub permalink for %s:L%d-L%d", meta.path, meta.lstart, meta.lend)

    if meta.started_in_visual then
        local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
        vim.api.nvim_feedkeys(esc, "n", false)
        vim.schedule(function() notify(vim.log.levels.INFO, msg .. " → clipboard") end)
    else
        notify(vim.log.levels.INFO, msg .. " → clipboard")
    end

    return url, meta, nil
end

return M
