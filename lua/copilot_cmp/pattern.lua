local pattern = {}

local ch_pairs = {
  ['('] = '%)',
  ['['] = '%]',
  ['{'] = '%}',
  [')'] = '%(',
  [']'] = '%[',
  ['}'] = '%{',
}

local fmt_char = {
  ['('] = '%(',
  ['['] = '%[',
  ['{'] = '%{',
  [')'] = '%)',
  [']'] = '%]',
  ['}'] = '%}',
}

-- check if text has pair for char c
local function text_has_pair(text, c)
  if not text or not c then return false end
  return text:find(ch_pairs[c]) ~= nil
end

-- check if text has char c
local function text_has_char(text, c)
  if not text or not c then return false end
  c = fmt_char[c] or c
  return text:find(c) ~= nil
end

local function get_text_after_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line_text = vim.api.nvim_buf_get_lines(0, row-1, row, false)[1]
  local suffix = line_text:sub(col+1)
  return suffix
end

-- get text after cursor and check if it has pair for char c
-- if present add it to text so it is there after replacement
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
