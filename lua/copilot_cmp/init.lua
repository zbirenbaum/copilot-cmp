local source = require('copilot_cmp.source')

local M = {}

---Registered client and source mapping.
M.client_source_map = {}

M.setup = function()
   if vim.fn.has('nvim-0.7') then
      vim.api.nvim_create_autocmd({"InsertEnter"}, {callback=M._on_insert_enter})
   else
      vim.api.nvim_command[[autocmd InsertEnter * lua require('copilot_cmp')._on_insert_enter()]]
   end
end
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
         'documentation',
         'detail',
         'additionalTextEdits',
      }
   })

   return capabilities
end

M._on_insert_enter = function()
  local cmp = require('cmp')
  local allowed_clients = {}

  -- register all active clients.
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    allowed_clients[client.id] = client
    if not M.client_source_map[client.id] then
      local s = source.new(client)
      if s:is_available() then
        M.client_source_map[client.id] = cmp.register_source('copilot', s)
      end
    end
  end

  -- register all buffer clients (early register before activation)
  for _, client in ipairs(vim.lsp.buf_get_clients(0)) do
    allowed_clients[client.id] = client
    if not M.client_source_map[client.id] then
      local s = source.new(client)
      if s:is_available() then
        M.client_source_map[client.id] = cmp.register_source('copilot', s)
      end
    end
  end

  -- unregister stopped/detached clients.
  for client_id, source_id in pairs(M.client_source_map) do
    if not allowed_clients[client_id] or allowed_clients[client_id]:is_stopped() then
      cmp.unregister_source(source_id)
      M.client_source_map[client_id] = nil
    end
  end
end

return M
