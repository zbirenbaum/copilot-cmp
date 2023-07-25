local source = require("copilot_cmp.source")
local capabilities = require("copilot_cmp.capabilities")

local log = require('copilot_cmp.vlog')
log.new({ level = "debug" }, true)

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
  log.debug("on_insert_enter")

  local find_buf_client = function()
    for _, client in ipairs(vim.lsp.get_active_clients()) do
      if client.name == "copilot" then return client end
    end
  end

  local cmp = require("cmp")
  local copilot = find_buf_client()
  if not copilot or M.client_source_map[copilot.id] then return end

  local s = source.new(copilot, opts)
  -- log.debug("source: ", s)
  if s:is_available() then
    log.debug("source is available, registering with copilot.id: " .. copilot.id)
    M.client_source_map[copilot.id] = cmp.register_source("copilot", s)
    -- log.debug("M.client_source_map[copilot.id]=" .. vim.inspect(M.client_source_map[copilot.id]) or "nil")
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
