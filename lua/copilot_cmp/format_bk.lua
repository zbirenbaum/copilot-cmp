local types = require('cmp.types')
local str_cmp = require('cmp.utils.str')

local get_line = function (line)
  local line_text = vim.api.nvim_buf_get_lines(0, line, line+1, false)[1]
  return line_text
end

local get_line_text = function ()
  local next_line = vim.api.nvim_win_get_cursor(0)[1]
  return get_line(next_line) or ""
end

local function split_remove_trailing_newline(str)
  local list = vim.fn.split(str, "\n")
  if list[#list] == "" then
    list[#list] = nil
  end
  return list
end

local get_text_after_cursor = function()
  local current_line = vim.api.nvim_get_current_line()
  current_line = current_line:sub(vim.api.nvim_win_get_cursor(0)[2]+1)
  return current_line or ""
end

local remove_string_from_end = function(str, str_to_remove)
  if str:sub(-#str_to_remove) == str_to_remove then
    return str:sub(1, -#str_to_remove - 1)
  end
  return str
end

local formatter = {}

formatter.deindent = function(text)
  local indent = string.match(text, '^%s*')
  if not indent then
    return text
  end
  return string.gsub(string.gsub(string.gsub(text, '^' .. indent, ''), '\n' .. indent, '\n'), '[\r|\n]$', '')
end

formatter.clean_insertion = function(text)
  local indent = string.match(text, '^%s*')
  if not indent then return text end
  local list = split_remove_trailing_newline(string.gsub(text, '^' .. indent, ''))
  list[1] = remove_string_from_end(list[1], get_text_after_cursor())
  if #list > 1 then
    list[#list] = remove_string_from_end(list[#list], get_line_text())
  end
  return remove_string_from_end(table.concat(list, '\n'), '\n')
end


local remove_string = function(str1, str2)
  local loc = str1:find("^%"..str2)
  return loc and str1:sub(loc,"") or str1
end
local trim = function (str)
  return str:gsub("%s*", "")
end

formatter.format_item = function(item, params)
  local ctx=params.context
  item = vim.tbl_extend('force', {}, item)
  item.text = item.text or item.displayText
  local cleaned = formatter.deindent(item.text)
  item['filterText'] = string.sub(ctx.cursor_before_line, params.offset+1) .. item.displayText
  print(vim.inspect(item.filterText))
  local prefix = string.sub(params.context.cursor_before_line, item.range.start.character + 1, item.range["end"].character)
  -- local prefix = formatter.deindent(string.sub(context.cursor_before_line, item.range.start.character + 1, item.range["end"].character))
  return {
    copilot = true, -- for comparator, only availiable in panel, not cycling
    label = item.filterText,
    score = item.score or nil,
    kind = 15,
    filterText = item.filterText,
    textEdit = {
      newText = item.completionText or formatter.clean_insertion(item.text), --handle for panelCompletions
      range = item.range
    },
    documentation = {
      kind = "markdown",
      value = "```" .. vim.bo.filetype .. "\n" .. cleaned .. "\n```"
    },
  }
end

formatter.format_completions = function(completions, params)
  local map_table = function ()
    local items = {}
    for _, item in ipairs(completions) do
      table.insert(items, formatter.format_item(item, params))
    end
    return items
  end
  return map_table()
end

return formatter
