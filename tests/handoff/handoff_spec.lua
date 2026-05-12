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

  it("prompts for Review Note text when :HandoffAddReviewNote is called without args", function()
    local file_path = write_temp_file("tests/tmp/review_command_prompt.lua", { "one", "two", "three" })
    local original_input = vim.ui.input

    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd.runtime({ "plugin/handoff.lua", bang = true })
    vim.ui.input = function(_, on_confirm)
      on_confirm("Prompted note")
    end

    vim.cmd.HandoffAddReviewNote()

    vim.ui.input = original_input

    assert.are.same({
      { reference = "tests/tmp/review_command_prompt.lua:2", note = "Prompted note" },
    }, plugin._list_review_notes())
  end)

  it("treats canceled interactive Review Note entry as a no-op with feedback", function()
    local file_path = write_temp_file("tests/tmp/review_command_prompt_cancel.lua", { "one", "two", "three" })
    local original_input = vim.ui.input
    local original_notify = vim.notify
    local notifications = {}

    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd.runtime({ "plugin/handoff.lua", bang = true })
    vim.ui.input = function(_, on_confirm)
      on_confirm(nil)
    end
    vim.notify = function(message)
      table.insert(notifications, message)
    end

    vim.cmd.HandoffAddReviewNote()

    vim.ui.input = original_input
    vim.notify = original_notify

    assert.are.same({}, plugin._list_review_notes())
    assert.matches("cancel", string.lower(notifications[1]))
  end)

  it("treats empty interactive Review Note submit as a no-op without mutating pending notes", function()
    local file_path = write_temp_file("tests/tmp/review_command_prompt_empty.lua", { "one", "two", "three" })
    local original_input = vim.ui.input
    local original_notify = vim.notify
    local notifications = {}

    vim.cmd.edit(file_path)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    plugin.add_review_note("Existing note")
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd.runtime({ "plugin/handoff.lua", bang = true })
    vim.ui.input = function(_, on_confirm)
      on_confirm("")
    end
    vim.notify = function(message)
      table.insert(notifications, message)
    end

    vim.cmd.HandoffAddReviewNote()

    vim.ui.input = original_input
    vim.notify = original_notify

    assert.are.same({
      { reference = "tests/tmp/review_command_prompt_empty.lua:1", note = "Existing note" },
    }, plugin._list_review_notes())
    assert.matches("cancel", string.lower(notifications[1]))
  end)

  it("exports all pending Review Notes as plain text lines to the + register", function()
    local file_path = write_temp_file("tests/tmp/review_export.lua", { "one", "two", "three" })

    vim.cmd.edit(file_path)
    vim.fn.setreg("+", "")
    plugin.add_review_note("First note", 1, 1)
    plugin.add_review_note("Second note", 3, 3)

    local exported = plugin.export_review_notes()

    assert.are.equal("tests/tmp/review_export.lua:1 First note\ntests/tmp/review_export.lua:3 Second note", exported)
    assert.are.equal(exported, vim.fn.getreg("+"))
  end)

  it("sorts exported Review Notes by path and then line order", function()
    local alpha_path = write_temp_file("tests/tmp/alpha.lua", { "a", "b", "c", "d" })
    local beta_path = write_temp_file("tests/tmp/beta.lua", { "a", "b", "c", "d" })

    vim.cmd.edit(beta_path)
    plugin.add_review_note("beta line 3", 3, 3)

    vim.cmd.edit(alpha_path)
    plugin.add_review_note("alpha line 4", 4, 4)
    plugin.add_review_note("alpha line 2", 2, 2)

    local exported = plugin.export_review_notes()

    assert.are.equal(
      "tests/tmp/alpha.lua:2 alpha line 2\ntests/tmp/alpha.lua:4 alpha line 4\ntests/tmp/beta.lua:3 beta line 3",
      exported
    )
  end)

  it("keeps pending Review Notes after export", function()
    local file_path = write_temp_file("tests/tmp/review_export_retained.lua", { "one", "two" })

    vim.cmd.edit(file_path)
    plugin.add_review_note("Keep me", 2, 2)

    plugin.export_review_notes()

    assert.are.same({
      { reference = "tests/tmp/review_export_retained.lua:2", note = "Keep me" },
    }, plugin._list_review_notes())
  end)

  it("clears pending Review Notes via public Lua API", function()
    local file_path = write_temp_file("tests/tmp/review_clear.lua", { "one", "two" })

    vim.cmd.edit(file_path)
    plugin.add_review_note("First", 1, 1)
    plugin.add_review_note("Second", 2, 2)

    plugin.clear_review_notes()

    assert.are.same({}, plugin._list_review_notes())
  end)

  it("exports and clears pending Review Notes via user commands", function()
    local file_path = write_temp_file("tests/tmp/review_export_clear_commands.lua", { "one", "two", "three" })

    vim.cmd.edit(file_path)
    vim.fn.setreg("+", "")
    vim.cmd.runtime({ "plugin/handoff.lua", bang = true })
    vim.cmd("1HandoffAddReviewNote First")
    vim.cmd("3HandoffAddReviewNote Third")

    vim.cmd.HandoffExportReviewNotes()

    assert.are.equal(
      "tests/tmp/review_export_clear_commands.lua:1 First\ntests/tmp/review_export_clear_commands.lua:3 Third",
      vim.fn.getreg("+")
    )

    vim.cmd.HandoffClearReviewNotes()
    assert.are.same({}, plugin._list_review_notes())
  end)
end)
