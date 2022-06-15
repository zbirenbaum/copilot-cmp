local formatter = require("copilot_cmp.format")
local util = require("copilot.util")
local handler = require("copilot.handlers")
local methods = { id = 0 }

-- TODO: Clean up cycling a bit
-- Compared to PanelCompletions, cycling isn't great
-- All these local methods just used by cycling is a pretty huge waste
local add_result = function (completion, params)
  if not completion then return end
  local bufnr = params.context.bufnr
  local row = params.context.cursor.row
  local existing_matches = methods.existing_matches
  existing_matches[bufnr][row][formatter.deindent(completion.text)] = completion
  return existing_matches[bufnr][row]
end

-- add multiple
local add_results = function (completions, params)
  local existing_matches_loc = {}
  for _, completion in ipairs(completions) do existing_matches_loc = add_result(completion, params) end
  return existing_matches_loc
end

methods.getCompletionsCycling = function (_, params, callback)
  local bufnr = params.context.bufnr
  local row = params.context.cursor.row
  methods.existing_matches[bufnr] = methods.existing_matches[bufnr] or {}
  methods.existing_matches[bufnr][row] = methods.existing_matches[bufnr][row] or {}

  vim.lsp.buf_request(0, "getCompletionsCycling", util.get_completion_params(), function(_, response)
    if not response or vim.tbl_isempty(response.completions) then return end --j
    methods.existing_matches[bufnr][row] = add_results(response.completions, params)
    local existing_matches = methods.existing_matches[bufnr][row]
    local completions = formatter.format_completions(vim.tbl_values(existing_matches or {}), params)
    callback({ IsIncomplete=true, items = completions })
  end)
  local completions = formatter.format_completions(vim.tbl_values(methods.existing_matches[bufnr][row] or {}), params)
  callback({ IsIncomplete=true, items = completions })
end


--[[
In the entirity of copilot.lua and copilot_cmp this is probably the most complex, but also elegant code

Every other way of doing this was slow, awful, or gave way too many suggestions from cache rather than new results

Somehow, though, this works way better than cycling ever did

getPanelCompletions's handler in copilot lsp returns in 3 parts:
  1. First, the actual immediately getPanel Completionsresponse is just how many you get max. this is useless and inaccurate information. The handler in the copilot lsp then triggers two notifications to dispatch
  2. It sends `PanelSolution` notification a # of times equal to however many completions it said it would in (1).
  3. It sends `PanelCompletionsDone` notification once after all PanelSolutions are sent.

Here's the breakdown on how I handle it:
  1. make a variable for ID that will keep track of calls to the function (in init)
  2. use the id to create_handlers pre-emptively with the current call's callbacks and params as variables in their scope every time getPanelCompletions is called
  3. the panelId field is returned along with the results of getPanelSolutions, then updating vim.lsp.handlers[handler].
  4. The calls to `handler` made here add callbacks to the config of the corresponding notification handler by adding them to a the module's callback table
  5. Each of the callbacks we add to PanelSolutions just inserts the solution into a table local to the create_handlers scope it was created in. If another one request hasbeen dispatched, it won't interfere
  6. PanelSolutionsDone's handler makes use of the id function to get the specific cmp callback and params that corresponds to the solutions that are now present in the results table. It then formats these completions and sends them to cmp
  7. Finally, clean up the hooks so that we don't eat up memory
--]]

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
  end)

  handler.add_handler_callback("PanelSolutionsDone", id, function()
    callback({ IsIncomplete = true, items = formatter.format_completions(vim.tbl_values(results), params) })
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
