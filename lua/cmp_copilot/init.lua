local source = require("cmp_copilot.source")

---Registered client and source mapping.
local M = {
  default_config = {
    event = { "InsertEnter", "LspAttach" },
    fix_pairs = true,
    update_on_keypress = true,
  },
  registered = false,
}
M.config = M.default_config

M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.default_config, opts or {})

  local function on_insert_enter()
    local clients = vim.lsp.get_clients
        and vim.lsp.get_clients({
          name = "copilot",
          bufnr = vim.api.nvim_get_current_buf(),
        })
      or vim.tbl_filter(function(client)
        return client.name == "copilot"
      end, vim.lsp.get_active_clients())

    if #clients == 0 then
      return
    end

    local ok, cmp = pcall(require, "cmp")
    if not ok then
      return
    end

    -- copilot launches a single instance, but it stays alive forever
    local s = source.new(clients[1], M.config)
    if s:is_available() then
      M.registered = cmp.register_source("copilot", s)
      return true -- unregister autocmd
    end
  end

  vim.api.nvim_create_autocmd(M.config.event, { callback = on_insert_enter })
end

return M
