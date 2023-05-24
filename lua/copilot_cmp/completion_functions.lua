local format = require("copilot_cmp.format")
local pattern = require("copilot_cmp.pattern")
local util = require("copilot.util")
local api = require("copilot.api")
-- local debounce = require ('copilot_cmp.debounce')

local methods = {
  id = 0,
  fix_pairs = true,
}

local function handle_suffix(text, suffix)
  local tbl = format.split(text)
  tbl[1] = pattern.set_suffix(tbl[1], suffix)
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
    if methods.fix_pairs then
      item.text = handle_suffix(item.text, ctx.cursor_after_line)
      item.displayText = handle_suffix(item.displayText, ctx.cursor_after_line)
    end

    local preview = format.get_preview(item)
    local label = format.get_label(item)
    local multi_line = format.to_multi_line(item)

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
        newText = item.text,
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

local id = 0
local existing = {}
local delay = 100

methods.getCompletionsCycling = function (self, params, callback)
  existing[id] = nil
  id = id+1

  local respond_callback = function(err, response)
    if err or not response or vim.tbl_isempty(response.completions) then
      return callback({isIncomplete = true, items = {}})
    end
    local completions = vim.tbl_values(response.completions)
    callback(format_completions(completions, params.context))
  end


  local cb = function ()
    api.get_completions_cycling(self.client, util.get_doc_params(), respond_callback)
  end

  local defer_callback = function ()
    local cb_id = id
    existing[cb_id] = cb
    vim.defer_fn(function ()
      if existing[cb_id] then
        existing[cb_id]()
      end
    end, delay)
  end

  defer_callback()
  return callback({isIncomplete = true, items = {}})
end


methods.init = function (completion_method, opts)
  methods.existing_matches = {}
  methods.id = 0
  methods.fix_pairs = opts.fix_pairs

  return methods[completion_method]
end

return methods
