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

local remove_trailing_newline = function (text)
  return text:gsub("\n[^\n]*(\n?)$", "%1")
end

format.get_preview = function (item)
  return apply_formatters(item.text, {
    deindent,
    remove_trailing_newline,
    label_text
  })
end

format.get_insert_text = function (item)
  return apply_formatters(item.displayText, {
    remove_leading_whitespace,
    deindent,
    remove_trailing_newline,
  })
end

format.get_filter_text = function(item)
  return deindent(item.text)
end

return format
