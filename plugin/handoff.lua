vim.api.nvim_create_user_command("HandoffCopyReference", function(opts)
  require("handoff").copy_reference(opts.line1, opts.line2)
end, { range = true })

vim.api.nvim_create_user_command("HandoffAddReviewNote", function(opts)
  if opts.args ~= "" then
    require("handoff").add_review_note(opts.args, opts.line1, opts.line2)
    return
  end

  vim.ui.input({ prompt = "Review Note: " }, function(input)
    if input == nil or input == "" then
      vim.notify("Review Note entry canceled")
      return
    end

    require("handoff").add_review_note(input, opts.line1, opts.line2)
  end)
end, { range = true, nargs = "?" })

vim.api.nvim_create_user_command("HandoffExportReviewNotes", function()
  require("handoff").export_review_notes()
end, {})

vim.api.nvim_create_user_command("HandoffClearReviewNotes", function()
  require("handoff").clear_review_notes()
end, {})

local group = vim.api.nvim_create_augroup("HandoffReviewNoteGhostText", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  group = group,
  callback = function(args)
    require("handoff").refresh_review_note_ghost_text(args.buf)
  end,
})
