local formatter= {}

local close_chars = { [')'] = true, [']'] = true, ['}'] = true }
local shorten = function (str)
  local short_prefix = string.sub(str, 0, 20)
  local short_suffix = string.sub(str, string.len(str)-15, string.len(str))
  local delimiter =  " ... "
  return short_prefix .. delimiter .. short_suffix
end

local get_indent_string = function (ctx)
  return ctx.cursor_before_line:match("^%s*")
end

local str_to_list = function (str)
  return vim.fn.split(str, "\n")
end

-- removes a line if and only if text at all values >= lineidx equals existing text with proper indentation
-- TODO: this would be much cleaner as a recursive function
local check_exists = function (text_list)

  local get_line_text = function (line)
    return vim.api.nvim_buf_get_lines(0, line, line+1, false)[1] or ""
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0)[1]
  local next_line = get_line_text(cursor_pos)

  local start_match = -1
  local match = false
  for i, line in ipairs(text_list) do
    if line == next_line then
      match = true
      start_match = i
    end
    if start_match > -1 and get_line_text(cursor_pos+(i-start_match)) ~= line then
      match = false
    end
  end
  if match then
    for idx = start_match, #text_list do text_list[idx] = nil end
  end
  return text_list
end

local format_insert_text = function (deindented, ctx)
  -- if ctx.cursor_after_line[1]

  local indent_string = get_indent_string(ctx)

  local text_list = str_to_list(deindented)

  --do this before check_exists so that we end after existing
  local fmt_info = {
    startl = ctx.cursor.row,
    endl = #text_list + ctx.cursor.row - 1,
    n_lines = #text_list,
  }
  -- this is necessary because first line starts at cursor pos
  for line_idx = 2, #text_list do
    text_list[line_idx] = indent_string .. text_list[line_idx]
  end
  text_list = check_exists(text_list)
  local fmt_string = table.concat(text_list, '\n')
  return fmt_string, fmt_info
end

local format_label_text = function (item)
  -- fix text matching for cmp (mostly)
  local text = item.text:gsub("^%s*", "")
  return string.len(text) > 40 and shorten(text) or text
end

local format_item = function(item, params)
  -- local after_without_ws = params.context.cursor_after_line:match("^%s*(.-)%s*$")
  -- if #after_without_ws > 0 and close_chars[after_without_ws] then
  --   item.text = item.text .. after_without_ws .. '\n'
  -- end
  local deindented = formatter.deindent(item.text)
  local insert_text, fmt_info = format_insert_text(deindented, params.context)
  local label_text = format_label_text(item)

  return {
    copilot = true, -- for comparator, only availiable in panel, not cycling
    score = item.score or nil,
    fmt_info = fmt_info,
    label = label_text,
    filterText = label_text:sub(0, label_text:len()-1),
    kind = 1,
    textEdit = {
      newText = insert_text,
      range = {
        start = item.range.start,
        ['end'] = params.context.cursor,
      }
    },
    documentation = {
      kind = "markdown",
      value = "```" .. vim.bo.filetype .. "\n" .. deindented .. "\n```"
    },
    dup = 1,
  }
end

formatter.deindent = function(text)
  local indent = string.match(text, '^%s*')
  if not indent then return text end
  return string.gsub(string.gsub(string.gsub(text, '^' .. indent, ''), '\n' .. indent, '\n'), '[\r|\n]$', '')
end

formatter.format_completions = function(completions, params)
  return {
    IsIncomplete = true,
    items = vim.tbl_map(function(item)
      return format_item(item, params)
    end, completions)
  }
end

return formatter
