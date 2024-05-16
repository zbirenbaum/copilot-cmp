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

  local find_buf_client = function()
    for _, client in ipairs(vim.lsp.get_clients()) do
      if client.name == "copilot" then return client end
    end
  end

  local cmp = require("cmp")
  local copilot = find_buf_client()
  if not copilot or M.client_source_map[copilot.id] then return end

  local s = source.new(copilot, opts)
  if s:is_available() then
    M.client_source_map[copilot.id] = cmp.register_source("copilot", s)
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
