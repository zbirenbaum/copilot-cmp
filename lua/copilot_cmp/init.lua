local source = require("copilot_cmp.source")
local capabilities = require("copilot_cmp.capabilities")

---Registered client and source mapping.
local M = {
  client_source_map = {},
  registered = false,
  default_capabilities = capabilities.default_capabilities,
  update_capabilities = capabilities.update_capabilities,
}

local default_opts = {
  event = { "InsertEnter", "LspAttach" },
  fix_pairs = true,
}

M._on_insert_enter = function(opts)
  local find_buf_clients = function()
    if vim.lsp.get_clients == nil then
      return vim.tbl_filter(function (client)
        return client.name == "copilot"
      end, vim.lsp.get_active_clients())
    end

    return vim.lsp.get_clients({
      name = "copilot",
      bufnr = vim.api.nvim_get_current_buf()
    })
  end

  local cmp = require("cmp")
  local clients = find_buf_clients()

  if #clients == 0 then
    return
  end

  for _, copilot in ipairs(clients) do
    if not M.client_source_map[copilot.id] then
      local s = source.new(copilot, opts)
      if s:is_available() then
        M.client_source_map[copilot.id] = cmp.register_source("copilot", s)
      end
    end
  end
end


M.setup = function(opts)
  opts = vim.tbl_deep_extend("force", default_opts, opts or {})
  -- just in case someone decides to set event to nil for some reason
  local startEvent = opts.event or { "InsertEnter", "LspAttach" }

  vim.api.nvim_create_autocmd(startEvent, {
    callback = function ()
      M._on_insert_enter(opts)
    end
  })
end

return M
