local pattern = {}


local ch_pairs = {
  ['('] = '%)',
  ['['] = '%]',
  ['{'] = '%}',
  [')'] = '%(',
  [']'] = '%[',
  ['}'] = '%{',
}

local function text_has_pair(text, c)
  return text:find(ch_pairs[c]) ~= nil
end

local function text_has_char(text, c)
  return text:find(c) ~= nil
end

local function get_text_after_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line_text = vim.api.nvim_buf_get_lines(0, row-1, row, false)[1]
  local suffix = line_text:sub(col+1)
  return suffix
end

function pattern.set_suffix(text, line_suffix)
  for i = 1, #line_suffix do
    local c = line_suffix:sub(i,i)
    if ch_pairs[c] and text_has_pair(text, c) and not text_has_char(text, c) then
      text = text .. c
    end
  end
  return text
end

return pattern
