local M = {}

local function assert_stable_file_path(path)
  if path == nil or path == "" then
    error("Cannot create a Reference without a stable file path")
  end
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

M.copy_reference = function(start_line, end_line)
  local path = vim.api.nvim_buf_get_name(0)
  assert_stable_file_path(path)

  local effective_start_line = start_line or vim.api.nvim_win_get_cursor(0)[1]
  local effective_end_line = end_line or effective_start_line
  local relative_path = resolve_reference_path(path)
  local reference = format_reference(relative_path, effective_start_line, effective_end_line)

  vim.fn.setreg("+", reference)

  return reference
end

return M
