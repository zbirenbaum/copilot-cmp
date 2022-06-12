local source = {}
local existing_matches = {}
local util = require("copilot.util")
local formatter = require("copilot_cmp.format")

source.new = function(client)
  local self = setmetatable({ timer = vim.loop.new_timer() }, { __index = source })
  self.client = client
  self.request_ids = {}
  return self
end

source.get_trigger_characters = function()
  return { "\t", "\n", ".", ":", "(", "'", '"', "[", ",", "#", "*", "@", "|", "=", "-", "{", "/", "\\", " ", "+", "?"}
end

source.is_available = function(self)
  -- client is stopped.
  if self.client.is_stopped() then
    return false
  end
  -- client is not attached to current buffer.
  if not vim.lsp.buf_get_clients(vim.api.nvim_get_current_buf())[self.client.id] then
    return false
  end
  if not self.client.name == "copilot" then
    return false
  end
  return true
end

source.complete = function(_, params, callback)
  existing_matches[params.context.bufnr] = existing_matches[params.context.bufnr] or {}
  existing_matches[params.context.bufnr][params.context.cursor.row] = existing_matches[params.context.bufnr][params.context.cursor.row] or { IsIncomplete = true }
  local existing = existing_matches[params.context.bufnr][params.context.cursor.row]
  local has_complete = false
  vim.lsp.buf_request(0, "getCompletionsCycling", util.get_completion_params(), function(_, response)
    if response and not vim.tbl_isempty(response.completions) then
      existing = vim.tbl_deep_extend("force", existing, formatter.format_completions(params, response.completions))
      has_complete = true
    end
    vim.schedule(function() callback(existing) end)
  end)
  if not has_complete then
    callback(existing)
  end
end

return source
