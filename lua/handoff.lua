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

M.copy_reference = function()
  local path = vim.api.nvim_buf_get_name(0)
  assert_stable_file_path(path)

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local relative_path = resolve_reference_path(path)
  local reference = string.format("%s:%d", relative_path, line)

  vim.fn.setreg("+", reference)

  return reference
end

return M
