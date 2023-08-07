local format = require("copilot_cmp.format")
local pattern = require("copilot_cmp.pattern")
local util = require("copilot.util")
local api = require("copilot.api")

local methods = {
  id = 0,
  fix_pairs = true,
}

local function handle_suffix(text, suffix)
  local tbl = format.split(text)
  -- tbl[1] = pattern.set_suffix(tbl[1], suffix)
  local res = ''
  for i, v in ipairs(tbl) do
    res = res .. v
    if i < #tbl then
      res = res .. '\n'
    end
  end
  return res
end

local format_completions = function(completions, ctx)
  local format_item = function(item)
    item.displayText = item.displayText or item.label
    item.text = item.text or item.label
    if methods.fix_pairs then
      item.text = handle_suffix(item.text, ctx.cursor_after_line)
      item.displayText = handle_suffix(item.displayText, ctx.cursor_after_line)
    end

    local preview = format.get_preview(item)
    local label = format.get_label(item)
    if item.range then
      local multi_line = format.to_multi_line(item)
    end

    return {
      copilot = true, -- for comparator, only availiable in panel, not cycling
      score = item.score or nil,
      label = label,
      kind = 1,
      insertText = item.text,
      cmp = {
        kind_hl_group = "CmpItemKindCopilot",
        kind_text = 'Copilot',
      },
      sortText = item.insertText,
      -- textEdit = {
      --   newText = item.text,
      --   insert = multi_line.insert,
      --   replace = multi_line.replace,
      -- },
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
      local i = format_item(item)
      print(vim.inspect(i))
      return i
    end, completions) or {}
  }
end

methods.getCompletionsCycling = function (self, params, callback)
  local respond_callback = function(err, response)
    if err or not response or vim.tbl_isempty(response) then
      return callback({isIncomplete = true, items = {}})
    end
    -- local completions = vim.tbl_values(response.completions or response)
    callback(format_completions(response, params.context))
  end
  api.get_completions_cycling(self.client, util.get_doc_params(), respond_callback)
  return callback({isIncomplete = true, items = {}})
end

methods.init = function (completion_method, opts)
  methods.existing_matches = {}
  methods.id = 0
  methods.fix_pairs = opts.fix_pairs
  return methods[completion_method]
end

return methods
