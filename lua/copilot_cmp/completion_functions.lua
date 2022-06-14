local formatter = require("copilot_cmp.format")
local util = require("copilot.util")
local handler = require("copilot.handlers")
local panel = require("copilot.extensions.panel")
local methods = {}

methods.verify = function (bufnr, row)
  methods.existing_matches[bufnr] = methods.existing_matches[bufnr] or {}
  methods.existing_matches[bufnr][row] = methods.existing_matches[bufnr][row] or {}
end

-- add single
methods.add_result = function (completion, bufnr, row)
  methods.verify(bufnr, row)
  methods.existing_matches[bufnr][row][completion.label] = completion
end

-- add multiple
methods.add_results = function (completions, bufnr, row)
  for _, completion in ipairs(completions) do
    methods.add_result(completion, bufnr, row)
  end
end

methods.get_completions = function (bufnr, row)
  return vim.tbl_values(methods.existing_matches[bufnr][row] or {})
end

methods.init_handlers = function ()
  local completed = function ()
    local bufnr = vim.api.nvim_get_current_buf()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local callback = methods.get_cmp_callback()
    callback({ isIncomplete = false, items = methods.get_completions(bufnr, row) })
  end

  -- this callback is local and independent of params and the cmp callback
  -- it must be this way in case an old completion request comes in
  -- in this scenario, the old request is still added to the persistent completions cache
  local add_completion_callback = function (completion)
    completion.text = completion.displayText
    local end_range = completion.range["end"]
    local bufnr = tonumber(completion.panelId)
    local row = end_range.line+1
    local cursor = { line = row-1, row = row, character = end_range.character, col = end_range.character+1 }
    local solution = formatter.format_item(completion, cursor)
    methods.add_result(solution, bufnr, row)
  end

  handler.add_handler_callback("PanelSolution", "cmp", add_completion_callback)

  handler.add_handler_callback("PanelSolutionsDone", "cmp", completed)
end

methods.getCompletionsCycling = function (_, params, callback)
  local bufnr = params.context.bufnr
  local row = params.context.cursor.row
  methods.verify(bufnr, row)
  vim.lsp.buf_request(0, "getCompletionsCycling", util.get_completion_params(), function(_, response)
    if not response or vim.tbl_isempty(response.completions) then
      callback({ IsIncomplete=true, items = methods.get_completions(bufnr, row) })
      return
    end
    local completions = formatter.format_completions(response.completions, params.context.cursor)
    methods.add_results(completions, bufnr, row)
    callback({ IsIncomplete=false, items = methods.get_completions(bufnr, row) })
  end)
  callback({ IsIncomplete=true, items = methods.get_completions(bufnr, row) })
end


methods.getPanelCompletions = function (self, params, callback)
  local cmp_callback = callback

  methods.get_cmp_callback = function ()
    return cmp_callback
  end

  if not self.panel then self.panel = panel.create(self.client) end
  local sent, id
  local bufnr = params.context.bufnr
  local row = params.context.cursor.row
  methods.verify(bufnr, row)
  if sent and id then panel.client.rpc.cancel_request(id) end
  sent, id = panel.send_request({ client = self.client, uri=tostring(bufnr) })
  if not self.initialized then
    methods.init_handlers()
    self.initialized = true
  end
  callback({ isIncomplete = true, items = methods.get_completions(bufnr, row) })
end

methods.init = function (completion_method)
  methods.existing_matches = {}
  return methods[completion_method]
end

return methods
