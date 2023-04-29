local format = require("copilot_cmp.format")
local util = require("copilot.util")
local api = require("copilot.api")
local methods = { id = 0 }


local format_completions = function(completions, ctx)
  local format_item = function(item)
    local preview = format.get_preview(item)
    local filter_text = format.get_filter_text(item)

    local cmp = {
      kind_hl_group = "CmpItemKindCopilot",
      kind_text = 'Copilot',
    }

    local documentation = {
      kind = "markdown",
      value = "```" .. vim.bo.filetype .. "\n" .. preview .. "\n```"
    }
    local range = {
      start = {
        line = ctx.cursor.line,
        character = ctx.cursor.character,
      },
      ['end'] = item.range['end'],
    }
    local textEdit = {
      newText = item.text,
      insert = range,
      replace = range,
    }
    return {
      copilot = true,
      label = preview,
      textEdit = textEdit,
      filterText = filter_text,
      cmp = cmp,
      documentation = documentation
    }
  end

--This list is not complete. Further typing should result in recomputing this list.
--Recomputed lists have all their items replaced (not appended) in the
--incomplete completion sessions.
-- isIncomplete: boolean;
  return {
    isIncomplete = true,
    items = #completions > 0 and vim.tbl_map(function(item)
      return format_item(item)
    end, completions) or {}
  }
end

methods.getCompletionsCycling = function (self, params, callback)
  local respond_callback = function(err, response)
    if err or not response or vim.tbl_isempty(response.completions) then
      return callback({items = {}})
    end
    local completions = vim.tbl_values(response.completions)
    callback(format_completions(completions, params.context))
  end
  api.get_completions_cycling(self.client, util.get_doc_params(), respond_callback)
  return callback({items = {}})
end

methods.init = function (completion_method)
  methods.existing_matches = {}
  methods.id = 0
  return methods[completion_method]
end

return methods
