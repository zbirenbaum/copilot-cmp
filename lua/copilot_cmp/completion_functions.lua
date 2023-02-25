local format = require("copilot_cmp.format")
local util = require("copilot.util")
local api = require("copilot.api")
local methods = { id = 0 }

local format_completions = function(completions, ctx, formatters)
  local format_item = function(item)
    -- local insert_text, fmt_info = formatters.insert_text(item, params.context)
    local preview = formatters.preview(item.text)
    local label_text = formatters.label(item)
    local insert_text = formatters.insert_text(item, ctx)
    return {
      copilot = true, -- for comparator, only availiable in panel, not cycling
      score = item.score or nil,
      label = label_text,
      filterText = label_text:sub(0, label_text:len()-1),
      kind = 1,
      cmp = {
        kind_hl_group = "CmpItemKindCopilot",
        kind_text = 'Copilot',
      },
      textEdit = {
        newText = insert_text,
        range = {
          start = item.range.start,
          ['end'] = ctx.cursor,
        }
      },
      documentation = {
        kind = "markdown",
        value = "```" .. vim.bo.filetype .. "\n" .. preview .. "\n```"
      },
      dup = 1,
    }
  end

  return {
    IsIncomplete = true,
    items = #completions > 0 and vim.tbl_map(function(item)
      return format_item(item)
    end, completions) or {}
  }
end

local add_results = function (completions, params)
  local results = {}
  -- normalize completion and use as key to avoid duplicates
  for _, completion in ipairs(completions) do
    results[format.deindent(completion.text)] = completion
  end
  return results
end

methods.getCompletionsCycling = function (self, params, callback)
  local respond_callback = function(err, response)
    if err then return err end
    if not response or vim.tbl_isempty(response.completions) then return end
    local completions = vim.tbl_values(add_results(response.completions, params))
    callback(format_completions(completions, params.context, self.formatters))
  end

  api.get_completions_cycling(self.client, util.get_doc_params(), respond_callback)
  -- Callback to cmp with empty completions so it doesn't freeze
  callback(format_completions({}, params.context, self.formatters))
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

---@param panelId string
local create_handlers = function (panelId, params, callback, formatters)
  local results = {}
  api.register_panel_handlers(panelId, {
    on_solution = function (solution)
      -- this standardizes the format of the response to be the same as cycling
      -- Cycling insertions have been empirically less buggy
      solution.range.start = {
        character = 0,
        line = solution.range.start.line,
      }
      solution.text = solution.displayText
      solution.displayText = solution.completionText
      results[format.deindent(solution.text)] = solution --ensure unique
      callback({
        IsIncomplete = true,
        items = format_completions(solution, params.context, formatters)
      })
    end,
    on_solutions_done = function()
      callback(format_completions(vim.tbl_values(results), params.context, formatters))
      vim.schedule(function()
        api.unregister_panel_handlers(panelId)
      end)
    end,
  })
end

local get_req_params = function (id)
  local req_params = util.get_doc_params()
  req_params.panelId = "copilot-cmp:" .. tostring(id)
  return req_params
end

methods.getPanelCompletions = function (self, params, callback)
  local req_params = get_req_params(methods.id)
  local respond_callback = function (err, _)
    methods.id = methods.id + 1
    if err then return end
    create_handlers(req_params.panelId, params, callback, self.formatters)
  end
  local sent, _ = api.get_panel_completions(self.client, req_params, respond_callback)
  if not sent then api.unregister_panel_handlers(req_params.panelId) end
  callback({ IsIncomplete = true, items = {}})
end

methods.init = function (completion_method)
  methods.existing_matches = {}
  methods.id = 0
  return methods[completion_method]
end

return methods
