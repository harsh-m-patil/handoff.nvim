## Problem Statement

Developers using AI coding agents inside a Neovim-based workflow need a fast way to hand off precise code context and structured feedback without manually typing file locations. Today, moving from "this exact code range" to "here is the feedback I want the agent to act on" is cumbersome, error-prone, and inconsistent across files.

## Solution

Handoff will let a developer create a precise **Reference** from the current line or selected line range, copy that **Reference** to the system clipboard, attach single-line **Review Notes** to a **Reference**, inspect pending **Review Notes** inside Neovim, and export all pending **Review Notes** as plain text lines suitable for pasting into an AI agent conversation.

## User Stories

1. As a developer using an AI coding agent, I want to copy a **Reference** for my current line, so that I can ask a quick question about a specific location in code.
2. As a developer using an AI coding agent, I want to copy a **Reference** for a selected line range, so that I can discuss a function or block without manually typing line numbers.
3. As a developer reviewing generated code, I want to attach a **Review Note** to my current line, so that I can give precise change feedback to the agent later.
4. As a developer reviewing generated code, I want to attach a **Review Note** to a selected line range, so that I can comment on multi-line code changes as one unit.
5. As a developer, I want a single-line selection to collapse to a compact single-line **Reference**, so that clipboard output stays readable.
6. As a developer, I want a multi-line selection to export as a start and end line range, so that the agent understands the full span I am referencing.
7. As a developer working inside a git repository, I want each **Reference** to use a git-root-relative path, so that pasted output is portable and easy to read.
8. As a developer working outside a git repository, I want each **Reference** to fall back to a working-directory-relative path, so that the plugin still works in non-git contexts.
9. As a developer, I want a **Review Note** to capture its **Reference** at creation time, so that later file movement or editor state changes do not change what I meant.
10. As a developer, I want to add multiple **Review Notes** to the same **Reference**, so that I do not lose nuance or accidentally overwrite earlier thoughts.
11. As a developer, I want pending **Review Notes** to stay in memory after export, so that I can retry a paste or inspect the output again before clearing it.
12. As a developer, I want a dedicated clear action, so that I can deliberately start a fresh review batch.
13. As a developer, I want all pending **Review Notes** exported together, so that I can send one coherent batch of feedback to the agent.
14. As a developer, I want exported **Review Notes** sorted by file path and line order, so that the output is predictable and easy for both humans and agents to scan.
15. As a developer, I want exported **Review Notes** in plain text with one note per line, so that I can paste them directly into chats without extra formatting cleanup.
16. As a developer, I want feedback after adding a **Review Note**, so that I know the note was captured and how many are still pending.
17. As a developer, I want a simple way to inspect pending **Review Notes** inside Neovim, so that in-memory state is not invisible.
18. As a developer, I want commands to work from normal mode, visual mode, and explicit Ex ranges, so that the workflow fits both ad hoc usage and automation.
19. As a developer, I want Lua functions in addition to user commands, so that I can build my own mappings and editor workflows.
20. As a developer, I do not want forced default keymaps, so that the plugin does not conflict with my existing setup.
21. As a developer, I want the plugin to error when a buffer has no stable file path, so that I do not accidentally create unusable **Reference** values.
22. As a developer, I want clipboard copying to target the system clipboard by default, so that the handoff to the AI agent is immediate.
23. As a developer, I want the visual workflow to preserve my place sensibly after acting on a selection, so that I can continue reviewing without disruption.
24. As a developer planning future iterations, I want the v1 model to leave room for **Change Sets** and **Change Hunks**, so that later git-based review workflows can build on the same language.
25. As a developer planning future iterations, I want a minimal v1 that solves the manual handoff problem first, so that the plugin can prove value before growing into a full review system.

## Implementation Decisions

- The current codebase is still a starter plugin scaffold, so the v1 implementation will replace the placeholder greeting behavior with a small public API centered on **Reference** creation and **Review Note** workflows.
- The design should revolve around a few deep modules with stable interfaces:
  - a **Reference resolver** that turns editor state or an explicit range into a normalized line-based **Reference** input
  - a **Path formatter** that converts a buffer path into the final repository-relative or working-directory-relative string form
  - a **Review Note store** that manages in-memory pending **Review Notes**, allows duplicates, reports counts, lists current state, and clears state explicitly
  - an **Export formatter** that sorts pending **Review Notes** by path and line order and renders plain-text one-note-per-line output
  - a thin **editor command adapter** that handles prompting, clipboard writes, user messages, and command registration
- **Reference** values are line-based only in v1. Column coordinates are intentionally excluded.
- Single-line selections and current-line actions use the compact `path:line` form. Multi-line selections use `path:start:end`.
- **Review Notes** are single-line text only in v1.
- **Review Notes** are captured and frozen at creation time rather than being recomputed during export.
- Pending **Review Notes** live only in memory in v1. They are not persisted across Neovim restarts.
- Export includes all pending **Review Notes**, not only notes for the current file.
- Export does not clear pending **Review Notes**. Clearing is a separate explicit action.
- A simple inspect flow should be included in v1 so users can view pending **Review Notes** before export or clear.
- The public surface should include separate commands for copying a **Reference**, adding a **Review Note**, exporting **Review Notes**, clearing **Review Notes**, and showing pending **Review Notes**.
- The plugin should also expose corresponding Lua functions so users can create their own keymaps and wrappers.
- No default keymaps should be installed by the plugin in v1.
- Commands should be range-aware so they can operate on the current line, a visual selection, or an explicit Ex range.
- If a buffer does not have a stable file path, creating a **Reference** or **Review Note** should fail clearly instead of inventing a synthetic path.
- Clipboard export should target the `+` register by default in v1.
- After adding a **Review Note**, the plugin should show a success message that includes the pending count.
- The v1 implementation should preserve a clean separation between the **Reference** and **Review Note** domain model and Neovim-specific UI behavior, so that later features like **Change Sets**, **Change Hunks**, markdown export, or persistent review sessions can be added without rewriting the core model.

## Testing Decisions

- A good test should validate externally observable behavior rather than internal helper structure. Tests should assert outcomes such as produced **Reference** values, stored **Review Notes**, exported text, error conditions, and command-visible behavior.
- The **Reference resolver** should be tested for current-line behavior, explicit line ranges, and single-line selection collapsing.
- The **Path formatter** should be tested for git-root-relative output, working-directory-relative fallback, and failure for unnamed buffers.
- The **Review Note store** should be tested for append behavior, duplicate support, pending counts, listing, export retention, and explicit clearing.
- The **Export formatter** should be tested for sorting by file path and line order and for plain-text one-note-per-line rendering.
- The command-facing layer should be tested for the main user workflows: copy **Reference**, add **Review Note**, export pending **Review Notes**, inspect pending **Review Notes**, and clear pending **Review Notes**.
- Tests should verify user-visible feedback such as success messages and should verify clipboard writes through stable Neovim interfaces rather than by asserting on internal plumbing.
- Prior art in the codebase is minimal and currently limited to starter-style plugin API tests. The new test suite should continue that lightweight automated style while expanding into behavior-focused tests for the new public workflows.

## Out of Scope

- **Change Set** and **Change Hunk** detection from git or any diff source
- Persistent storage of pending **Review Notes** across editor restarts
- Markdown or JSON export formats
- Column-based **Reference** values
- Multi-line **Review Note** text
- Automatic review of only the current file during export
- Automatic clearing after export
- Default keymaps
- Rich editable scratch review buffers beyond a simple inspect flow
- Integrations with specific AI agents, chat tools, or external services beyond clipboard-based handoff
- Cross-session merge, conflict resolution, or synchronization of pending **Review Notes**

## Further Notes

- The current domain glossary already distinguishes **Reference**, **Review Note**, **Change Set**, and **Change Hunk**. The implementation should use those terms consistently in naming, docs, and tests.
- No ADR is necessary at this stage because the current decisions are mostly reversible v1 product and API choices rather than hard-to-reverse architectural commitments.
- Intended issue-tracker label for this PRD: `needs-triage`.
