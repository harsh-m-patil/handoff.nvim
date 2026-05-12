local M = {}
local review_notes = {}
local ghost_text_namespace = vim.api.nvim_create_namespace("handoff_review_notes")
local SINGLE_NOTE_PREVIEW_MAX_CHARS = 40

local function assert_stable_file_path(path)
  if path == nil or path == "" then
    error("Cannot create a Reference without a stable file path")
  end
end

local function assert_single_line_review_note(note)
  if type(note) ~= "string" or note == "" then
    error("Review Note must be a non-empty single-line string")
  end

  if note:find("\n") then
    error("Review Note must be single-line text")
  end
end

local function normalize_line_range(start_line, end_line)
  local normalized_start = math.min(start_line, end_line)
  local normalized_end = math.max(start_line, end_line)
  return normalized_start, normalized_end
end

local function truncate_with_ellipsis(text, max_chars)
  if vim.fn.strchars(text) <= max_chars then
    return text
  end

  if max_chars <= 3 then
    return vim.fn.strcharpart(text, 0, max_chars)
  end

  return vim.fn.strcharpart(text, 0, max_chars - 3) .. "..."
end

local function path_relative_to(base, path)
  local normalized_base = vim.fn.fnamemodify(base, ":p")
  if not normalized_base:match("/$") then
    normalized_base = normalized_base .. "/"
  end

  local normalized_path = vim.fn.fnamemodify(path, ":p")
  if normalized_path:sub(1, #normalized_base) == normalized_base then
    return normalized_path:sub(#normalized_base + 1)
  end

  return nil
end

local function resolve_reference_path(path)
  local directory = vim.fn.fnamemodify(path, ":h")
  local git_root = vim.fn.systemlist({ "git", "-C", directory, "rev-parse", "--show-toplevel" })[1]

  if vim.v.shell_error == 0 and git_root and git_root ~= "" then
    local git_relative_path = path_relative_to(git_root, path)
    if git_relative_path then
      return git_relative_path
    end
  end

  return vim.fn.fnamemodify(path, ":.")
end

M.setup = function(_)
end

local function format_reference(path, start_line, end_line)
  if start_line == end_line then
    return string.format("%s:%d", path, start_line)
  end

  return string.format("%s:%d:%d", path, start_line, end_line)
end

local function create_reference(start_line, end_line)
  local path = vim.api.nvim_buf_get_name(0)
  assert_stable_file_path(path)

  local effective_start_line = start_line or vim.api.nvim_win_get_cursor(0)[1]
  local effective_end_line = end_line or effective_start_line
  local normalized_start, normalized_end = normalize_line_range(effective_start_line, effective_end_line)
  local relative_path = resolve_reference_path(path)

  return format_reference(relative_path, normalized_start, normalized_end)
end

M.copy_reference = function(start_line, end_line)
  local reference = create_reference(start_line, end_line)

  vim.fn.setreg("+", reference)

  return reference
end

M.add_review_note = function(note, start_line, end_line)
  assert_single_line_review_note(note)

  local reference = create_reference(start_line, end_line)
  local entry = { reference = reference, note = note }

  table.insert(review_notes, entry)
  M.refresh_review_note_ghost_text()
  vim.notify(string.format("Review Note added (%d pending)", #review_notes))

  return {
    reference = entry.reference,
    note = entry.note,
    pending_count = #review_notes,
  }
end

M._list_review_notes = function()
  local entries = {}
  for i, entry in ipairs(review_notes) do
    entries[i] = { reference = entry.reference, note = entry.note }
  end

  return entries
end

local function parse_reference(reference)
  local path, start_line, end_line = reference:match("^(.-):(%d+):(%d+)$")
  if path then
    return path, tonumber(start_line), tonumber(end_line)
  end

  path, start_line = reference:match("^(.-):(%d+)$")
  if path then
    local parsed_start = tonumber(start_line)
    return path, parsed_start, parsed_start
  end

  return reference, math.huge, math.huge
end

local function ghost_text_for_notes(notes_on_line)
  if #notes_on_line == 1 then
    local preview = truncate_with_ellipsis(notes_on_line[1], SINGLE_NOTE_PREVIEW_MAX_CHARS)
    return string.format("%s", preview)
  end

  return string.format("%d notes", #notes_on_line)
end

local function render_review_note_ghost_text_for_buffer(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ghost_text_namespace, 0, -1)

  local absolute_path = vim.api.nvim_buf_get_name(bufnr)
  if absolute_path == nil or absolute_path == "" then
    return
  end

  local buffer_reference_path = resolve_reference_path(absolute_path)
  local notes_by_start_line = {}

  for _, entry in ipairs(review_notes) do
    local note_path, start_line, end_line = parse_reference(entry.reference)
    if note_path == buffer_reference_path then
      local anchor_line = math.min(start_line, end_line)
      notes_by_start_line[anchor_line] = notes_by_start_line[anchor_line] or {}
      table.insert(notes_by_start_line[anchor_line], entry.note)
    end
  end

  local sorted_lines = {}
  for line, _ in pairs(notes_by_start_line) do
    table.insert(sorted_lines, line)
  end
  table.sort(sorted_lines)

  for _, line in ipairs(sorted_lines) do
    vim.api.nvim_buf_set_extmark(bufnr, ghost_text_namespace, line - 1, 0, {
      virt_text = { { ghost_text_for_notes(notes_by_start_line[line]), "Comment" } },
      virt_text_pos = "eol",
    })
  end
end

M.refresh_review_note_ghost_text = function(bufnr)
  if bufnr ~= nil then
    render_review_note_ghost_text_for_buffer(bufnr)
    return
  end

  for _, listed_bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(listed_bufnr) then
      render_review_note_ghost_text_for_buffer(listed_bufnr)
    end
  end
end

M.export_review_notes = function()
  local sorted_entries = {}

  for i, entry in ipairs(review_notes) do
    local path, start_line, end_line = parse_reference(entry.reference)
    sorted_entries[i] = {
      reference = entry.reference,
      note = entry.note,
      path = path,
      start_line = start_line,
      end_line = end_line,
      original_index = i,
    }
  end

  table.sort(sorted_entries, function(a, b)
    if a.path ~= b.path then
      return a.path < b.path
    end

    if a.start_line ~= b.start_line then
      return a.start_line < b.start_line
    end

    if a.end_line ~= b.end_line then
      return a.end_line < b.end_line
    end

    return a.original_index < b.original_index
  end)

  local lines = {}
  for i, entry in ipairs(sorted_entries) do
    lines[i] = string.format("%s %s", entry.reference, entry.note)
  end

  local output = table.concat(lines, "\n")
  vim.fn.setreg("+", output)

  return output
end

M.clear_review_notes = function()
  review_notes = {}
  M.refresh_review_note_ghost_text()
end

M._clear_review_notes = function()
  M.clear_review_notes()
end

return M
