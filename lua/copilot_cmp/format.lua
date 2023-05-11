local format= {}

local apply_formatters = function (text, callbacks)
  for _, cb in ipairs(callbacks) do
    text = cb(text)
  end
  return text
end

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

local deindent = function(text)
  local indent = string.match(text, '^%s*')
  if not indent then return text end
  return string.gsub(string.gsub(string.gsub(text, '^' .. indent, ''), '\n' .. indent, '\n'), '[\r|\n]$', '')
end

local remove_leading_whitespace = function (text)
  return text:gsub("^%s*", "")
end

local remove_trailing = function (text)
  return text:gsub('[ \t]+%f[\r\n%z]', '')
end

-- local remove_trailing_newline = function (text)
--   return text:gsub("\n[^\n]*(\n?)$", "%1")
-- end

format.get_label = function (item)
  return apply_formatters(item.text, {
    deindent,
    remove_trailing,
    label_text
  })
end

format.get_insert_text = function (item)
  return apply_formatters(item.displayText, {
    remove_leading_whitespace,
    deindent,
    remove_trailing,
  })
end

format.get_preview = function(item)
  return deindent(item.text)
end

format.split = function (inputstr, sep)
  sep = sep or inputstr:find('\r') and '\r' or '\n'
  if sep == nil then sep = "\n" end
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end
format.to_multi_line = function (item)
  local splitText = format.split(item.text)
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

return format
