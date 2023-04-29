local format = require("copilot_cmp.format")
local util = require("copilot.util")
local api = require("copilot.api")
local methods = { id = 0 }

local function to_multi_line(item)
  local function split (inputstr, sep)
    sep = inputstr:find('\r') and '\r' or '\n'
    if sep == nil then sep = "\n" end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
    end
    return t
  end

  local splitText = split(item.text)
  local offset = {
    start = {
      line = item.range.start.line,
      character = item.range.start.character
    },
    ['end'] = {
      line = item.range['end'].line + (#splitText - 1),
      character = #splitText[#splitText]
    }
  }
  return {
    newText = table.concat(splitText, '\n'),
    insert = offset,
    replace = offset
  }
end

local format_completions = function(completions, ctx)
  local format_item = function(item)
    local preview = format.get_preview(item)
    local label = format.get_label(item)
    local multi_line = to_multi_line(item)
    return {
      copilot = true, -- for comparator, only availiable in panel, not cycling
      score = item.score or nil,
      label = label,
      kind = 1,
      cmp = {
        kind_hl_group = "CmpItemKindCopilot",
        kind_text = 'Copilot',
      },
      sortText = item.text,
      textEdit = {
        newText = multi_line.newText,
        insert = multi_line.insert,
        replace = multi_line.replace,
      },
      documentation = {
        kind = "markdown",
        value = "```" .. vim.bo.filetype .. "\n" .. preview .. "\n```"
      },
      dup = 0,
    }
  end

  return {
    IsIncomplete = true,
    items = #completions > 0 and vim.tbl_map(function(item)
      return format_item(item)
    end, completions) or {}
  }
end

methods.getCompletionsCycling = function (self, params, callback)
  local respond_callback = function(err, response)
    if err or not response or vim.tbl_isempty(response.completions) then
      return callback({isIncomplete = true, items = {}})
    end
    local completions = vim.tbl_values(response.completions)
    callback(format_completions(completions, params.context))
  end
  api.get_completions_cycling(self.client, util.get_doc_params(), respond_callback)
  return callback({isIncomplete = true, items = {}})
end

methods.init = function (completion_method)
  methods.existing_matches = {}
  methods.id = 0
  return methods[completion_method]
end

return methods
