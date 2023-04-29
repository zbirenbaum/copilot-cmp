local source = {}

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
  if self.client.is_stopped() then
    return false
  end
  -- client is not attached to current buffer.
  if not vim.lsp.get_active_clients({ bufnr = vim.api.nvim_get_current_buf() })[self.client.id] then
    return false
  end
  if not self.client.name == "copilot" then
    return false
  end
  return true
end

local defaults = {}

source.new = function(client, opts)
  opts = vim.tbl_deep_extend('force', defaults, opts or {})
  -- remove option since currently only one method is available
  -- local completion_fn = opts.method or "getCompletionsCycling"

  local completion_functions = require("copilot_cmp.completion_functions")
  local self = setmetatable({ timer = vim.loop.new_timer() }, { __index = source })

  local setup_execution_functions = function ()
    local executions = opts.executions or {}
    return executions
  end

  self.executions = setup_execution_functions()
  self.client = client
  self.request_ids = {}
  self.complete = completion_functions.init('getCompletionsCycling')

  return self
end

return source
