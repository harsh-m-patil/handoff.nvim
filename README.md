# handoff.nvim

Neovim plugin for copying a line or line-range **Reference** to the system clipboard for AI handoff workflows.

Current public interface:

- Commands:
  - `:HandoffCopyReference`
  - `:HandoffAddReviewNote {note}`
- Lua API:
  - `require("handoff").copy_reference(start_line?, end_line?)`
  - `require("handoff").add_review_note(note, start_line?, end_line?)`

Behavior:

- copies the current line as `path:line`
- copies a multi-line range as `path:start:end`
- collapses a single-line range to the compact `path:line` form
- accepts command ranges from normal mode, visual mode, and explicit Ex ranges
- adds single-line Review Notes for current line or range selections
- freezes each Review Note's Reference at creation time
- appends duplicate Review Notes on the same Reference
- shows pending-count feedback after adding a Review Note
- uses a git-root-relative path when inside a git repository
- falls back to a working-directory-relative path outside git
- errors clearly for unnamed buffers without overwriting the `+` register
