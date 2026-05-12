# Handoff

Handoff is a Neovim plugin for moving code-review context between the editor and external AI coding agents. It exists to turn editor selections and human feedback into precise references that can be pasted into agent conversations.

## Language

**Reference**:
A location in a file, expressed as a repository-relative or working-directory-relative file path plus either one line number or a multi-line range, with single-line selections collapsed to one line number.
_Avoid_: Pointer, citation, span

**Review Note**:
A single-line human comment attached to a **Reference** captured at creation time, kept in memory in v1 until the user clears it or exits Neovim.
_Avoid_: Annotation, feedback item, remark

**Change Set**:
A collection of code changes being reviewed together.
_Avoid_: Diff, patch, session

**Change Hunk**:
A contiguous changed region within a **Change Set**.
_Avoid_: Block, chunk

## Relationships

- A **Review Note** belongs to exactly one **Reference**
- A **Reference** may have zero, one, or many **Review Notes**
- A **Reference** may refer to either the current line or a selected line range
- A **Change Set** contains one or more **Change Hunks**
- A **Review Note** may refer to a **Reference** inside a **Change Hunk**

## Example dialogue

> **Dev:** "I want to ask the agent about this function."
> **Domain expert:** "Copy a **Reference** for the selected range. If you want to suggest a change, attach a **Review Note** to that **Reference** and export the pending notes when you're done."

## Flagged ambiguities

- "comment" was resolved to **Review Note** when referring to human feedback on code.
- "filename:start:end" was resolved to **Reference** when referring to a file location payload.
- "selection" was resolved to line-based **Reference** values for v1, not column-based coordinates.
- "filename" in a **Reference** was resolved to a configurable relative path, defaulting to git-root-relative when available and otherwise working-directory-relative.
- single-line selected **Reference** values were resolved to the compact `path:line` form instead of `path:line:line`.
- creating a **Review Note** without a selection was resolved to use the current line; creating one with a selection uses the selected line range.
- v1 includes both standalone **Reference** copying and in-memory **Review Note** capture because they support different agent-assisted workflows.
- **Reference** values attached to **Review Notes** were resolved to be captured and frozen at note-creation time, not recomputed later during export.
- **Review Notes** were resolved to single-line text only in v1 to keep export plain-text and one-note-per-line.
- exported **Review Notes** were resolved to plain text lines in v1, with markdown as a possible later format.
- pending **Review Notes** were resolved to in-memory state only for v1, not persisted across Neovim restarts.
- multiple **Review Notes** on the same **Reference** were resolved as allowed in v1; no deduplication or replacement is implied.
- export in v1 was resolved to export all pending **Review Notes**, not only those from the current file.
- exported **Review Notes** were resolved to sorted output by file path and then line order for predictable review.
- exporting does not clear pending **Review Notes** in v1; they remain in memory until explicitly cleared or until Neovim exits.
- `:HandoffAddReviewNote` input mode was resolved to dual behavior: argument mode for scripted/non-interactive use and prompt mode when called with no args.
- inline display of **Review Notes** was resolved to ghost text shown at each **Reference** start line, only in buffers matching each note's path.
- interactive note entry cancel semantics were resolved as no-op on empty submit or `<Esc>`, with a cancellation notification and no error.
- when multiple **Review Notes** share a start line, ghost text was resolved to a compact count indicator (for example, `💬 3 notes`) instead of rendering all note text inline.
- when exactly one **Review Note** exists on a start line, ghost text was resolved to a truncated single-note preview with a length cap rather than full unrestricted text.
- ghost-text rendering was resolved to refresh after note mutations (add/clear) and on buffer/window re-entry, not on continuous cursor/text-change events.
- exporting **Review Notes** was resolved to leave ghost-text state unchanged because export does not mutate pending notes.
- selection anchoring for note capture and ghost-text placement was resolved to use normalized ascending line order (`min(line1,line2)` as start), not visual-anchor direction.
- ghost text placement on the start line was resolved to end-of-line rendering to minimize interference with code text.
- ghost-text anchoring was resolved to frozen captured line numbers (no code-movement tracking) to match frozen **Reference** semantics in v1.
- interactive **Review Note** entry was resolved to use `vim.ui.input` so prompt UI can be enhanced by user-installed UI adapters.
- `:HandoffAddReviewNote` was resolved to dual-mode parsing via optional args: provided args add immediately; empty args trigger interactive prompt.
- prompt UX was resolved to `vim.ui.input` for v1 (not strictly line-anchored), deferring custom line-anchored floating input to a later iteration.
