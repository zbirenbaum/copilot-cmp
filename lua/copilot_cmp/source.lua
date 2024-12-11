local source = {
  executions = {},
}

function source:get_keyword_pattern()
  return '.'
end

source.get_trigger_characters = function()
  return {'.'}
end

-- executes before selection
source.resolve = function (self, completion_item, callback)
  for _, fn in ipairs(self.executions) do
    completion_item = fn(completion_item)
  end
  callback(completion_item)
end

source.is_available = function(self)
  -- client is stopped.
  if self.client.is_stopped() or not self.client.name == "copilot" then
    return false
  end


  local get_source_client = function ()
    if vim.lsp.get_clients == nil then
      return vim.lsp.get_active_clients({
        bufnr = vim.api.nvim_get_current_buf(),
        id = self.client.id
      })
    end
    return vim.lsp.get_clients({
      bufnr = vim.api.nvim_get_current_buf(),
      id = self.client.id
    })
  end

  return next(get_source_client()) ~= nil
end

source.execute = function (_, completion_item, callback)
  callback(completion_item)
end

source.new = function(client, opts)
  local completion_functions = require("copilot_cmp.completion_functions")

  local self = setmetatable({
    timer = vim.loop.new_timer()
  }, { __index = source })

  self.client = client
  self.request_ids = {}
  self.complete = completion_functions.init('getCompletions', opts)

  return self
end

return source
