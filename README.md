# handoff.nvim

Neovim plugin for copying a current-line **Reference** to the system clipboard for AI handoff workflows.

Current public interface:

- Command: `:HandoffCopyReference`
- Lua API: `require("handoff").copy_reference()`

Behavior:

- copies the current line as `path:line`
- uses a git-root-relative path when inside a git repository
- falls back to a working-directory-relative path outside git
- errors clearly for unnamed buffers without overwriting the `+` register
