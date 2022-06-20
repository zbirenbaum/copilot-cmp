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

-- shorten line, probably add config params for this later
local shorten = function (str)
  local short_prefix = string.sub(str, 0, 20)
  local short_suffix = string.sub(str, string.len(str)-15, string.len(str))
  local delimiter =  " ... "
  return short_prefix .. delimiter .. short_suffix
end

local get_line_list = function (text)
  local indent = string.match(text, '^%s*')
  if not indent then return text end
  local list = split_remove_trailing_newline(string.gsub(text, '^' .. indent, ''))
  return list
end

formatter.clean_insertion = function(text)
  local line_list = type(text) == "table" and text or get_line_list(text)
  line_list[1] = remove_string_from_end(line_list[1], get_text_after_cursor())
  if #line_list > 1 then
    line_list[#line_list] = remove_string_from_end(line_list[#line_list], get_line_text())
  end
  return remove_string_from_end(table.concat(line_list, '\n'), '\n')
end

-- So this method is awful but it isn't my fault
--
-- for getCompletionsCycling: \
--    text = the whole line \
--    displayText = just the part of the line after existing text \
--    no completionText field
--
-- for getPanelCompletions: \
--   no text field \
--   displayText = the whole line (opposite in cycling)
--   completionText = just the part after existing text (displayText in cycling)

formatter.format_item = function(item, params)
  local ctx = params.context
  local cleaned = formatter.deindent(item.text)

  -- local prefix = ctx.cursor_before_line:sub(0, params.offset)

  local text = item.text:gsub("^%s*", "")
  -- fix text matching for cmp (mostly)
  -- local label_prefix = prefix:gsub("^%s*", "")
  local label = text
  -- local line_list = get_line_list(label)
  local final_label = string.len(label) > 40 and shorten(label) or label
  -- local final_text = formatter.clean_insertion(line_list)

  return {
    copilot = true, -- for comparator, only availiable in panel, not cycling
    score = item.score or nil,
    label = final_label,
    kind = 1,
    textEdit = {
      newText = formatter.clean_insertion(text),
      range = {
        start = item.range.start,
        ['end'] = params.context.cursor,
      }
    },
    documentation = {
      kind = "markdown",
      value = "```" .. vim.bo.filetype .. "\n" .. cleaned .. "\n```"
    },
    dup = 0,
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
