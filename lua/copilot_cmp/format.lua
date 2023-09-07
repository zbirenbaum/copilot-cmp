local format= {}

local string = require('string')

local label_text = function (text)
  local shorten = function (str)
    local short_prefix = string.sub(str, 0, 20)
    local short_suffix = string.sub(str, string.len(str)-15, string.len(str))
    local delimiter =  " ... "
    return short_prefix .. delimiter .. short_suffix
  end
  text = text:gsub("^%s*", "")
  return string.len(text) > 40 and shorten(text) or text
end

format.get_indent_string = function (text)
  return string.match(text, '^%s*')
end

format.get_newline_char = function (text)
  if string.find(text, '\n') ~= nil then
    return '\n'
  else
    return nil
  end
end

-- deindents all lines and sets relative indent level to indent_level spaces
format.deindent = function(text, rel_indent_level)
  local indent = string.match(text, '^%s*')
  if not indent then return text end

  local deindented = string.gsub(string.gsub(string.gsub(text, '^' .. indent, ''), '\n' .. indent, '\n'), '[\r|\n]$', '')
  local rel_indent = string.rep(' ', rel_indent_level)

  if #indent == 0  or not rel_indent or rel_indent == indent then
    return deindented
  end

  local lines = format.split(deindented, '\n')
  for k, v in ipairs(lines) do
    lines[k] = string.gsub(v, '^' .. indent, rel_indent)
  end
  return table.concat(lines, '\n')
end

format.add_indent = function(text, indent_level)
  if not indent_level or indent_level == 0 then return text end

  local lines = format.split(text, '\n')
  local indent_str = string.rep(' ', indent_level)
  for k, v in ipairs(lines) do
    lines[k] = indent_str .. v
  end
  return table.concat(lines, '\n')
end

format.remove_leading_whitespace = function (text)
  return text:gsub("^%s*", "")
end

format.split = function (inputstr, sep)
  sep = sep or inputstr:find('\r') and '\r' or '\n'
  if sep == nil then sep = "\n" end
  if not string.find(inputstr, '[\r|\n]') then
    return {inputstr}
  end
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

format.get_indent_offset = function(text)
  return #text - #format.remove_leading_whitespace(text)
end

format.to_multi_line = function (item, ctx, rel_indent_level)
  -- get indent on line before cursor
  local indent_offset = format.get_indent_offset(ctx.cursor_before_line)

  -- deindent everything and set all relative indents to `indent_width_fn` spaces
  local preview = format.deindent(item.text, rel_indent_level)

  -- add indent equal to whitespace before cursor to every line
  local text = format.add_indent(preview, indent_offset)

  -- get abbreviated label
  local label =  label_text(text)
  local splitText = format.split(text)
  local offset = {
    start = {
      line = item.range.start.line,
      character = item.range.start.character
    },
    ['end'] = {
      line = item.range['end'].line,
      character = #splitText[1]
    }
  }
  return {
    preview = preview,
    label = label,
    text = text,
    insert = offset,
    replace = offset
    -- range = range
  }
end

return format
