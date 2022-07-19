local fmt = {}

fmt.fmt = function(params, item)
  local prefix = string.sub(params.context.cursor_before_line, item.range.start.character + 1, item.position.character)
  return {
    label = prefix .. item.displayText,
    textEdit = {
      range = item.range,
      newText = item.text,
    },
    documentation = {
      kind = 'markdown',
      value = table.concat({
        '```' .. vim.api.nvim_buf_get_option(0, 'filetype'),
        fmt.deindent(item.text),
        '```'
      }, '\n'),
    }
  }
end
fmt.complete = function (params, completions)
  return vim.tbl_map(function(item) return fmt.fmt(params, item) end, completions)
end

fmt.deindent = function(text)
  local indent = string.match(text, '^%s*')
  if not indent then
    return text
  end
  return string.gsub(string.gsub(text, '^' .. indent, ''), '\n' .. indent, '\n')
end

return fmt
