# gh_permalink.nvim

Yank **GitHub permalinks** for the current file & line(s) straight from Neovim.

* **Normal mode** → permalink to the **current line**
* **Visual mode** → permalink to the **selected line range**
* Uses the **exact commit (SHA)** for a true permalink
* Works with **SSH or HTTPS** remotes, including **GitHub Enterprise**

No configuration, no dependencies. You control the keymaps.

## Requirements

* **Neovim**: 0.8+ (uses `vim.system` if present; otherwise falls back to `systemlist`)
* **git** CLI available in `$PATH`

## Install

### vim.pack

```lua
vim.pack.add(
    { src = "https://github.com/vieitesss/gh_permalink.nvim" }
)
```

### lazy.nvim

```lua
{
    "vieitesss/gh_permalink.nvim",
}
```

## Usage

* In **Normal mode**, trigger your mapping to copy a permalink to the current line.
* In **Visual mode**, trigger your mapping to copy a permalink to the selected line range.

The URL looks like:

```
https://github.example.com/owner/repo/blob/<COMMIT_SHA>/path/to/file.ext#L10-L20
```

It is copied to the `+` (and `*`) registers, so your OS clipboard receives it (assuming a clipboard provider).

## API

```lua
-- Return the permalink without copying.
-- @return url|nil, meta|nil, err|nil
local url, meta, err = require("gh_permalink").get_url()

-- Copy the permalink (to '+' and '*'), exit Visual first, then notify.
-- @return url|nil, meta|nil, err|nil
local url, meta, err = require("gh_permalink").yank()
```

`meta` table fields:

* `path` — file path relative to repo root
* `lstart`, `lend` — line range
* `commit` — commit SHA (HEAD)
* `base` — repo base URL (e.g., `https://github.com/owner/repo`)
* `started_in_visual` — `true` if the call started in Visual mode

## Keymap examples

Choose whatever you like:

```lua
-- Yank permalink (normal: line, visual: range)
vim.keymap.set({ "n", "x" }, "<leader>gy",
    function() require("gh_permalink").yank() end,
    { desc = "Yank GitHub permalink to clipboard" }
)

-- Command version (optional)
vim.api.nvim_create_user_command("PermalinkYank", function()
    require("gh_permalink").yank()
end, {})
```

---

## Troubleshooting & limitations

* **“Not inside a Git repository.”**
  Open a file that lives under a Git worktree.

* **“No Git remote found (e.g. origin).”**
  Add a remote: `git remote add origin git@github.com:owner/repo.git`.

* **“Remote is not a GitHub host.”**
  Only GitHub/GitHub Enterprise URLs are supported currently.

* **Brand-new or ignored file**
  If the file is not tracked at `HEAD`, the permalink may 404 until you commit it.

* **Local commit not pushed**
  The permalink points to your local SHA; GitHub won’t show it until you push.

* **Unsaved/scratch buffers**
  Buffers without a file on disk can’t be linked.

* **Symlinks / outside repo**
  If the buffer file resolves outside the repo root, the relative path cannot be computed.


## Why commit permalinks?

Branch URLs can drift as code changes. Using the exact commit SHA ensures the link always refers to the same content — perfect for code reviews, tickets, and documentation.
