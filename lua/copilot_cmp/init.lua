local source = require('copilot_cmp.source')

local M = {}

---Registered client and source mapping.
M.client_source_map = {}

M.setup = function()
  vim.cmd([[
    augroup cmp_nvim_lsp
      autocmd!
      autocmd InsertEnter * lua require'cmp_nvim_lsp'._on_insert_enter()
    augroup END
  ]])
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

---Refresh sources on InsertEnter.
M._on_insert_enter = function()
   local cmp = require('cmp')

   local allowed_clients = {}
   local function add_clients(tbl)
      for _, client in ipairs(tbl) do
         if client.name == "copilot" and not M.client_source_map[client.id] then
            local s = source.new(client)
            if s:is_available() then
               M.client_source_map[client.id] = cmp.register_source('copilot', s)
            end
         end
      end
   end
   add_clients(vim.lsp.get_active_clients())
   add_clients(vim.lsp.buf_get_clients())
   -- unregister stopped/detached clients.
   for client_id, source_id in pairs(M.client_source_map) do
      cmp.unregister_source(source_id)
      M.client_source_map[client_id] = nil
   end
end

return M
