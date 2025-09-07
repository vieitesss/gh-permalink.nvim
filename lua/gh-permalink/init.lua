local M = {}

local core = require("gh-permalink.core")
local git = require("gh-permalink.git")
local lvl = vim.log.levels

---Return a GitHub permalink URL for the current buffer and selection.
---@return string|nil url
---@return table|nil meta -- { path, lstart, lend, commit, base, started_in_visual }
---@return string|nil err
function M.get_url()
    local started_in_visual, lstart, lend = core.get_line_range_and_mode()

    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    if file == "" then
        return nil, nil, "Buffer has no file on disk."
    end

    local dir = vim.fn.fnamemodify(file, ":h")
    local root = git.git_root(dir)
    if not root or root == "" then
        return nil, nil, "Not inside a Git repository."
    end

    local rel = core.relpath(file, root)
    if not rel then
        return nil, nil, "Could not compute path relative to repo root."
    end

    local remote = git.pick_remote(root)
    if not remote or remote == "" then
        return nil, nil, "No Git remote found (e.g. origin)."
    end

    local base = core.to_https_github_base(remote)
    if not base or not base:find("github", 1, true) then
        return nil,
            nil,
            "Remote is not a GitHub host. Only GitHub/GH Enterprise are supported."
    end

    local commit = git.current_commit(root)
    if not commit or commit == "" then
        return nil, nil, "Could not determine current commit (HEAD)."
    end

    if not git.tracked_in_head(root, rel) then
        core.notify(
            lvl.WARN,
            "File is not tracked at HEAD. Link may 404 until committed."
        )
    end

    local anchor = (lstart == lend) and ("#L" .. lstart)
        or ("#L" .. lstart .. "-L" .. lend)
    local url = string.format(
        "%s/blob/%s/%s%s",
        base,
        commit,
        core.urlencode_path(rel),
        anchor
    )

    return url,
        {
            path = rel,
            lstart = lstart,
            lend = lend,
            commit = commit,
            base = base,
            started_in_visual = started_in_visual,
        },
        nil
end

---Copy permalink to clipboard (exits Visual first) and notify.
---@return string|nil url
---@return table|nil meta
---@return string|nil err
function M.yank()
    local url, meta, err = M.get_url()
    if not url or not meta then
        core.notify(lvl.ERROR, err or "Failed to build permalink.")
        return nil, nil, err
    end

    vim.fn.setreg("+", url)
    pcall(vim.fn.setreg, "*", url)

    local msg = (meta.lstart == meta.lend)
            and string.format(
                "Yanked GitHub permalink for %s:L%d",
                meta.path,
                meta.lstart
            )
        or string.format(
            "Yanked GitHub permalink for %s:L%d-L%d",
            meta.path,
            meta.lstart,
            meta.lend
        )

    if meta.started_in_visual then
        local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
        vim.api.nvim_feedkeys(esc, "n", false)
        vim.schedule(function()
            core.notify(lvl.INFO, msg .. " → clipboard")
        end)
    else
        core.notify(lvl.INFO, msg .. " → clipboard")
    end

    return url, meta, nil
end

return M
