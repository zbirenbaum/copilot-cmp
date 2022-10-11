local format= {}

format.shorten = function (str)
  local short_prefix = string.sub(str, 0, 20)
  local short_suffix = string.sub(str, string.len(str)-15, string.len(str))
  local delimiter =  " ... "
  return short_prefix .. delimiter .. short_suffix
end

local get_indent_string = function (ctx)
  return ctx.cursor_before_line:match("^%s*")
end

local str_to_list = function (str)
  -- if would be great to have this in lua but doesn't work well
  return vim.fn.split(str, "\n")
end


format.get_format_text_list = function (item, ctx)
  -- removes a line if and only if text at all values >= lineidx equals existing text with proper indentation
  -- TODO: this would be much cleaner as a recursive function
  local deindented = format.deindent(item.text)
  local indent_string = get_indent_string(ctx)

  local text_list = str_to_list(deindented)

  -- do this before check_exists so that we end after existing
  local fmt_info = {
    startl = ctx.cursor.row,
    endl = #text_list + ctx.cursor.row - 1,
    n_lines = #text_list,
  }
  -- this is necessary because first line starts at cursor pos
  for line_idx = 2, #text_list do
    text_list[line_idx] = indent_string .. text_list[line_idx]
  end
  return text_list, fmt_info
end

local remove_suffix_match = function (suffix, end_text)
  local reverse_et = string.reverse(end_text)
  local reverse_suffix = string.reverse(suffix)
  local min_len = string.len(suffix) < string.len(end_text) and #suffix or #end_text
  local counter = 1
  local unmatch = false
  while(counter <= min_len and not unmatch) do
    if reverse_suffix[counter] == reverse_et[counter] then
      counter = counter + 1
    else
      unmatch = true
    end
  end
  local modified = string.sub(end_text, 1, string.len(end_text)-(counter-1))
  return modified
end

format.format_remove_existing = function (item, ctx)
  -- this is an additional step to try and remove trailing text that exists

  local get_line_text = function (line, start_col)
    return vim.api.nvim_buf_get_text(0, line, start_col or 0, line+1, -1, {})[1]
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local suffix = ctx.cursor_after_line
  local text_list, fmt_info = format.get_format_text_list(item, ctx)
  if suffix and suffix ~= '' then
    text_list[#text_list] = remove_suffix_match(suffix, text_list[#text_list])
  end

  -- do not do nextline checks if on the last line
  if vim.api.nvim_buf_line_count(0) <= vim.fn.line('.') then
    return text_list, fmt_info
  end

  local next_line = get_line_text(cursor_pos[1])
  local start_match = -1
  local match = false
  for i, line in ipairs(text_list) do
    if line == next_line then
      match = true
      start_match = i
    end
    if start_match > -1 and get_line_text(cursor_pos[1]+(i-start_match)) ~= line then
      match = false
    end
  end
  if match then
    for idx = start_match, #text_list do text_list[idx] = nil end
  end
  return text_list, fmt_info
end

format.format_insert_text = function (item, ctx, remove_existing)
  local format_fn = remove_existing and format.format_remove_existing or format.get_format_text_list
  -- default to get_format_text_list
  local text_list, fmt_info = format_fn(item, ctx)
  local fmt_string = table.concat(text_list, '\n')
  return fmt_string, fmt_info
end

format.remove_existing = function (item, ctx)
  -- call format_insert_text with remove_existing set to true
  -- hacky but keeps the config consistent rather than mix callbacks and booleans
  return format.format_insert_text(item, ctx, true)
end

format.format_label_text = function (item)
  local text = item.text:gsub("^%s*", "")
  return string.len(text) > 40 and format.shorten(text) or text
end

format.deindent = function(text)
  local indent = string.match(text, '^%s*')
  if not indent then return text end
  return string.gsub(string.gsub(string.gsub(text, '^' .. indent, ''), '\n' .. indent, '\n'), '[\r|\n]$', '')
end

return format
