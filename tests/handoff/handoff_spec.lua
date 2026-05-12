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
    plugin._clear_review_notes()
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

  it("copies a multi-line Reference via an explicit Ex range", function()
    local file_path = write_temp_file("tests/tmp/ex_range.lua", { "first line", "second line", "third line" })

    vim.cmd.edit(file_path)
    vim.fn.setreg("+", "")
    vim.cmd.runtime({ "plugin/handoff.lua", bang = true })

    vim.cmd("2,3HandoffCopyReference")

    assert.are.equal("tests/tmp/ex_range.lua:2:3", vim.fn.getreg("+"))
  end)

  it("copies current-line Reference to the + register via the public Lua API", function()
    local file_path = write_temp_file("tests/tmp/lua_api.lua", { "alpha", "beta", "gamma" })

    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.fn.setreg("+", "")

    plugin.copy_reference()

    assert.are.equal("tests/tmp/lua_api.lua:3", vim.fn.getreg("+"))
  end)

  it("collapses a single-line range to the compact Reference form", function()
    local file_path = write_temp_file("tests/tmp/single_line_range.lua", { "alpha", "beta", "gamma" })

    vim.cmd.edit(file_path)
    vim.fn.setreg("+", "")

    local reference = plugin.copy_reference(2, 2)

    assert.are.equal("tests/tmp/single_line_range.lua:2", reference)
    assert.are.equal("tests/tmp/single_line_range.lua:2", vim.fn.getreg("+"))
  end)

  it("copies a multi-line Reference via a visual selection command range", function()
    local file_path = write_temp_file("tests/tmp/visual_range.lua", { "alpha", "beta", "gamma" })

    vim.cmd.edit(file_path)
    vim.fn.setreg("+", "")
    vim.cmd.runtime({ "plugin/handoff.lua", bang = true })
    vim.fn.setpos("'<", { 0, 1, 1, 0 })
    vim.fn.setpos("'>", { 0, 3, 1, 0 })

    vim.cmd("'<,'>HandoffCopyReference")

    assert.are.equal("tests/tmp/visual_range.lua:1:3", vim.fn.getreg("+"))
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

  it("adds a current-line Review Note via the public Lua API with pending-count feedback", function()
    local file_path = write_temp_file("tests/tmp/review_current.lua", { "one", "two", "three" })
    local original_notify = vim.notify
    local notifications = {}

    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.notify = function(message)
      table.insert(notifications, message)
    end

    local result = plugin.add_review_note("Rename this variable")

    vim.notify = original_notify

    assert.are.same({
      reference = "tests/tmp/review_current.lua:2",
      note = "Rename this variable",
      pending_count = 1,
    }, result)

    assert.are.same({
      { reference = "tests/tmp/review_current.lua:2", note = "Rename this variable" },
    }, plugin._list_review_notes())
    assert.matches("1 pending", notifications[1])
  end)

  it("adds a selected-range Review Note via the public Lua API", function()
    local file_path = write_temp_file("tests/tmp/review_range.lua", { "alpha", "beta", "gamma" })

    vim.cmd.edit(file_path)

    local result = plugin.add_review_note("Extract this block", 1, 3)

    assert.are.same({
      reference = "tests/tmp/review_range.lua:1:3",
      note = "Extract this block",
      pending_count = 1,
    }, result)

    assert.are.same({
      { reference = "tests/tmp/review_range.lua:1:3", note = "Extract this block" },
    }, plugin._list_review_notes())
  end)

  it("appends duplicate Review Notes on the same Reference", function()
    local file_path = write_temp_file("tests/tmp/review_duplicates.lua", { "alpha", "beta", "gamma" })

    vim.cmd.edit(file_path)

    plugin.add_review_note("First note", 2, 2)
    local second = plugin.add_review_note("Second note", 2, 2)

    assert.are.equal(2, second.pending_count)
    assert.are.same({
      { reference = "tests/tmp/review_duplicates.lua:2", note = "First note" },
      { reference = "tests/tmp/review_duplicates.lua:2", note = "Second note" },
    }, plugin._list_review_notes())
  end)

  it("freezes each Review Note Reference at creation time", function()
    local file_path = write_temp_file("tests/tmp/review_frozen.lua", { "one", "two", "three" })

    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    plugin.add_review_note("First capture")

    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    plugin.add_review_note("Second capture")

    assert.are.same({
      { reference = "tests/tmp/review_frozen.lua:1", note = "First capture" },
      { reference = "tests/tmp/review_frozen.lua:3", note = "Second capture" },
    }, plugin._list_review_notes())
  end)

  it("adds a current-line Review Note via :HandoffAddReviewNote", function()
    local file_path = write_temp_file("tests/tmp/review_command_current.lua", { "one", "two", "three" })

    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd.runtime({ "plugin/handoff.lua", bang = true })

    vim.cmd("HandoffAddReviewNote Use clearer naming")

    assert.are.same({
      { reference = "tests/tmp/review_command_current.lua:2", note = "Use clearer naming" },
    }, plugin._list_review_notes())
  end)

  it("adds a selected-range Review Note via :HandoffAddReviewNote", function()
    local file_path = write_temp_file("tests/tmp/review_command.lua", { "one", "two", "three" })
    local original_notify = vim.notify
    local notifications = {}

    vim.cmd.edit(file_path)
    vim.cmd.runtime({ "plugin/handoff.lua", bang = true })
    vim.notify = function(message)
      table.insert(notifications, message)
    end

    vim.cmd("2,3HandoffAddReviewNote Tighten loop boundaries")

    vim.notify = original_notify

    assert.are.same({
      { reference = "tests/tmp/review_command.lua:2:3", note = "Tighten loop boundaries" },
    }, plugin._list_review_notes())
    assert.matches("1 pending", notifications[1])
  end)
end)
