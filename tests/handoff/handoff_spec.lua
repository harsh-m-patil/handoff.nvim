local plugin = require("handoff")
local repo_root = vim.fn.getcwd()

local function write_temp_file(relative_path, lines)
  local file_path = vim.fn.fnamemodify(relative_path, ":p")
  vim.fn.mkdir(vim.fn.fnamemodify(file_path, ":h"), "p")
  vim.fn.writefile(lines, file_path)
  return file_path
end

describe("handoff", function()
  after_each(function()
    vim.cmd.cd(repo_root)
    vim.fn.delete(vim.fn.fnamemodify("tests/tmp", ":p"), "rf")
  end)
  it("copies current-line Reference to the + register via :HandoffCopyReference", function()
    local file_path = write_temp_file("tests/tmp/current_line.lua", { "first line", "second line", "third line" })

    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.fn.setreg("+", "")
    vim.cmd.runtime({ "plugin/handoff.lua", bang = true })

    vim.cmd.HandoffCopyReference()

    assert.are.equal("tests/tmp/current_line.lua:2", vim.fn.getreg("+"))
  end)

  it("copies current-line Reference to the + register via the public Lua API", function()
    local file_path = write_temp_file("tests/tmp/lua_api.lua", { "alpha", "beta", "gamma" })

    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.fn.setreg("+", "")

    plugin.copy_reference()

    assert.are.equal("tests/tmp/lua_api.lua:3", vim.fn.getreg("+"))
  end)

  it("uses a git-root-relative path when the buffer is inside a git repository", function()
    local original_cwd = vim.fn.getcwd()
    local nested_cwd = original_cwd .. "/tests/tmp/nested"
    local file_path = write_temp_file("tests/tmp/git_relative.lua", { "one", "two" })

    vim.fn.mkdir(nested_cwd, "p")

    vim.cmd.cd(nested_cwd)
    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.fn.setreg("+", "")

    local ok, reference = pcall(plugin.copy_reference)
    vim.cmd.cd(original_cwd)

    assert.is_true(ok)
    assert.are.equal("tests/tmp/git_relative.lua:2", reference)
    assert.are.equal("tests/tmp/git_relative.lua:2", vim.fn.getreg("+"))
  end)

  it("falls back to a working-directory-relative path outside a git repository", function()
    local original_cwd = vim.fn.getcwd()
    local temp_root = vim.fn.tempname()
    local cwd = temp_root .. "/workspace"
    local file_path = cwd .. "/src/non_git.lua"

    vim.fn.mkdir(vim.fn.fnamemodify(file_path, ":h"), "p")
    vim.fn.writefile({ "red", "blue", "green" }, file_path)

    vim.cmd.cd(cwd)
    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.fn.setreg("+", "")

    local ok, reference = pcall(plugin.copy_reference)
    vim.cmd.cd(original_cwd)

    assert.is_true(ok)
    assert.are.equal("src/non_git.lua:3", reference)
    assert.are.equal("src/non_git.lua:3", vim.fn.getreg("+"))
  end)

  it("fails clearly and does not overwrite the + register for an unnamed buffer", function()
    vim.cmd.enew({ bang = true })
    vim.fn.setreg("+", "keep-me")

    local ok, err = pcall(plugin.copy_reference)

    assert.is_false(ok)
    assert.matches("stable file path", err)
    assert.are.equal("keep-me", vim.fn.getreg("+"))
  end)

  it("surfaces the same unnamed-buffer failure through :HandoffCopyReference", function()
    vim.cmd.enew({ bang = true })
    vim.fn.setreg("+", "keep-me")
    vim.cmd.runtime({ "plugin/handoff.lua", bang = true })

    local ok, err = pcall(vim.cmd.HandoffCopyReference)

    assert.is_false(ok)
    assert.matches("stable file path", err)
    assert.are.equal("keep-me", vim.fn.getreg("+"))
  end)
end)
