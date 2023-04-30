local source = require("copilot_cmp.source")

---Registered client and source mapping.
local M = {
  client_source_map = {},
  registered = false,
}

---Setup cmp-nvim-lsp source.
local if_nil = function(val, default)
  if val == nil then return default end
  return val
end

M.update_capabilities = function(capabilities, override)
  override = override or {}
  local completionItem = capabilities.textDocument.completion.completionItem
  completionItem.snippetSupport = if_nil(override.snippetSupport, true)
  completionItem.preselectSupport = if_nil(override.preselectSupport, true)
  completionItem.insertReplaceSupport = if_nil(override.insertReplaceSupport, true)
  completionItem.labelDetailsSupport = if_nil(override.labelDetailsSupport, true)
  completionItem.deprecatedSupport = if_nil(override.deprecatedSupport, true)
  completionItem.commitCharactersSupport = if_nil(override.commitCharactersSupport, true)
  completionItem.tagSupport = if_nil(override.tagSupport, { valueSet = { 1 } })
  completionItem.resolveSupport = if_nil(override.resolveSupport, {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
    },
  })
  return capabilities
end

local find_buf_client = function()
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    if client.name == "copilot" then return client end
  end
end

M.setup = function(opts)
  opts = opts or {}
  M._on_insert_enter = function()
    local cmp = require("cmp")
    local copilot = find_buf_client()
    if copilot and not M.client_source_map[copilot.id] then
      local s = source.new(copilot, opts)
      if s:is_available() then
        M.client_source_map[copilot.id] = cmp.register_source("copilot", s)
      end
    end
  end

  local startEvent = opts.event or { "InsertEnter" }
  vim.api.nvim_create_autocmd(startEvent, { callback = M._on_insert_enter })
end

return M
