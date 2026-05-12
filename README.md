# handoff.nvim

Neovim plugin for copying a line or line-range **Reference** to the system clipboard for AI handoff workflows.

## Example config

```lua
vim.pack.add({ "https://github.com/harsh-m-patil/handoff.nvim" })

require("handoff").setup()

vim.keymap.set("n", "<leader>ha", "<cmd>HandoffAddReviewNote<CR>", { desc = "Handoff: add review note" })
vim.keymap.set("n", "<leader>he", "<cmd>HandoffExportReviewNotes<CR>", { desc = "Handoff: export review notes" })
```

Current public interface:

- Commands:
  - `:HandoffCopyReference`
  - `:HandoffAddReviewNote [note]`
    - with `{note}`: adds the note directly (non-interactive)
    - without args: prompts via `vim.ui.input()` (interactive)
  - `:HandoffExportReviewNotes`
  - `:HandoffClearReviewNotes`
- Lua API:
  - `require("handoff").copy_reference(start_line?, end_line?)`
  - `require("handoff").add_review_note(note, start_line?, end_line?)`
  - `require("handoff").export_review_notes()`
  - `require("handoff").clear_review_notes()`

Behavior:

- copies the current line as `path:line`
- copies a multi-line range as `path:start:end`
- collapses a single-line range to the compact `path:line` form
- accepts command ranges from normal mode, visual mode, and explicit Ex ranges
- adds single-line Review Notes for current line or range selections
- supports dual-mode note entry for `:HandoffAddReviewNote`:
  - non-interactive when `{note}` is provided
  - interactive prompt when called without args
  - canceled or empty interactive submit is a no-op with cancellation feedback
- freezes each Review Note's Reference at creation time
- appends duplicate Review Notes on the same Reference
- shows pending-count feedback after adding a Review Note
- renders inline ghost text (`virt_text` at end-of-line) for pending notes in matching buffers
  - one note on a line: shows note preview, truncated to 40 chars with `...` on overflow
  - multiple notes on same start line: shows compact count (e.g. `2 notes`)
  - range notes are anchored to the normalized start line
- refreshes ghost text on `BufEnter`/`WinEnter`, and clears it when notes are cleared
- exports all pending Review Notes to the `+` register as plain text (`<reference> <note>`, one per line)
- sorts exported Review Notes by path and line order
- keeps pending Review Notes after export until explicitly cleared
- uses a git-root-relative path when inside a git repository
- falls back to a working-directory-relative path outside git
- errors clearly for unnamed buffers without overwriting the `+` register
