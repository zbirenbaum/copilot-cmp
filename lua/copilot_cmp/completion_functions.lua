local formatter = require("copilot_cmp.format")
local util = require("copilot.util")
local handler = require("copilot.handlers")
local methods = { id = 0 }
local test_fmt = require("copilot_cmp.test.test_formatter")

-- TODO: Clean up cycling a bit
-- Compared to PanelCompletions, cycling isn't great
-- All these local methods just used by cycling is a pretty huge waste
methods.getCompletionsCycling = function (_, params, callback)
  vim.lsp.buf_request(0, "getCompletionsCycling", util.get_completion_params(), function(_, response)
    if not response or vim.tbl_isempty(response.completions) then return end
    local completions = test_fmt.complete(params, response.completions)
    callback(completions)
  end)
  callback({ IsIncomplete=true, items = {} })
end

local create_handlers = function (id, params, callback)
  local results = {}
  id = tostring(id)
  handler.add_handler_callback("PanelSolution", id, function (solution)
    -- this standardizes the format of the response to be the same as cycling
    -- Cycling insertions have been empirically less buggy
    solution.range.start = {
      character = 0,
      line = solution.range.start.line,
    }
    solution.text = solution.displayText
    solution.displayText = solution.completionText
    results[formatter.deindent(solution.text)] = solution --ensure unique
    callback({
      IsIncomplete = true,
      items = formatter.format_item(solution, params)
    })
  end)

  handler.add_handler_callback("PanelSolutionsDone", id, function()
    callback({ IsIncomplete = false, items = formatter.format_completions(vim.tbl_values(results), params) })
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
  local sent, _ = request("getPanelCompletions", req_params(id), respond_callback)
  if not sent then handler.remove_all_name(id) end
  callback({ IsIncomplete = true, items = {}})
end

methods.init = function (completion_method)
  methods.existing_matches = {}
  methods.id = 0
  return methods[completion_method]
end

return methods
