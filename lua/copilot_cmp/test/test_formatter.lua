local fmt = {}

local split = function (s, delimiter)
  local result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match);
  end
  return result;
end

fmt.fmt = function(params, item)
  local prefix = string.sub(params.context.cursor_before_line, item.range.start.character + 1, item.position.character)
  local filter = prefix .. item.displayText
  return {
    -- word = fmt.deindent(filter),
    label = (filter),
    filterText = fmt.deindent(item.text),
    -- dup = true,
    textEdit = {
      range = {
        ["start"] = item.range["start"],
        ["end"] = item.range["end"],
      },
      newText = fmt.deindent(item.text),
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
  if not indent then return text end
  return string.gsub(string.gsub(text, '^' .. indent, ''), '\n' .. indent, '\n')
end

return fmt
