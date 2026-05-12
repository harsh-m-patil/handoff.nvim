vim.api.nvim_create_user_command("HandoffCopyReference", function(opts)
  require("handoff").copy_reference(opts.line1, opts.line2)
end, { range = true })

vim.api.nvim_create_user_command("HandoffAddReviewNote", function(opts)
  require("handoff").add_review_note(opts.args, opts.line1, opts.line2)
end, { range = true, nargs = 1 })

vim.api.nvim_create_user_command("HandoffExportReviewNotes", function()
  require("handoff").export_review_notes()
end, {})

vim.api.nvim_create_user_command("HandoffClearReviewNotes", function()
  require("handoff").clear_review_notes()
end, {})
