local formatter = require("copilot_cmp.format")
local util = require("copilot.util")
local handler = require("copilot.handlers")
local panel = require("copilot.extensions.panel")
local methods = { id = 0 }

-- 1. setup handlers to recieve notifications
-- 2. recieve cmp callback and info
-- 3. ???
-- 4. send request to copilot
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


local create_handlers = function (id, params, callback)
  local results = {}
  id = tostring(id)

  handler.add_id_callback("PanelSolution", id, function (solution)
    table.insert(results, solution)
  end)

  handler.add_handler_callback("PanelSolutionsDone", id, function()
    callback({ IsIncomplete = false, items = formatter.format_completions(results, params) })
    vim.schedule(function () handler.remove_all_name(id) end)
  end)
end

local req_params = function (id)
  local req_params = util.get_completion_params()
  req_params.panelId = tostring(id)
  return req_params
end

methods.getPanelCompletions = function (self, params, callback)
  local request = self.client.rpc.request
  local id = methods.id
  local respond_callback = function (err, _)
    methods.id = methods.id + 1
    if err then return end
    create_handlers(id, params, callback)
  end
  request("getPanelCompletions", req_params(id), respond_callback)
end

methods.init = function (completion_method)
  methods.existing_matches = {}
  methods.id = 0
  return methods[completion_method]
end

return methods
