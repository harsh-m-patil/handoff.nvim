vim.api.nvim_create_user_command("HandoffCopyReference", function()
  require("handoff").copy_reference()
end, {})
