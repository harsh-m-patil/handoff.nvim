vim.api.nvim_create_user_command("HandoffCopyReference", function(opts)
  require("handoff").copy_reference(opts.line1, opts.line2)
end, { range = true })
