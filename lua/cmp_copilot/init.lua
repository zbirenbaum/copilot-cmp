local source = require("cmp_copilot.source")

---Registered client and source mapping.
local M = {
  default_config = {
    event = { "InsertEnter", "LspAttach" },
    fix_pairs = true,
  },
  registered = false,
}
M.config = M.default_config

M._on_insert_enter = function()
  if M.registered then
    return true -- unregister autocmd
  end

  local copilot
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    if client.name == "copilot" then
      copilot = client
      break
    end
  end

  if not copilot then
    return
  end

  local ok, cmp = pcall(require, "cmp")
  if not ok then
    return
  end

  local s = source.new(copilot, M.config)
  if s:is_available() then
    M.registered = cmp.register_source("copilot", s)
    return true -- unregister autocmd
  end
end

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.default_config, opts or {})

  vim.api.nvim_create_autocmd(M.config.event, { callback = M._on_insert_enter })
end

return M
