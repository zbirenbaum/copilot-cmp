local source = {}
local util = require("copilot.util")
local existing_matches = {}

source.new = function(client)
  local self = setmetatable({ timer = vim.loop.new_timer() }, { __index = source })
  self.client = client
  self.request_ids = {}
  return self
end

source.get_trigger_characters = function()
  return { "\t", "\n", ".", ":", "(", "'", '"', "[", ",", "#", "*", "@", "|", "=", "-", "{", "/", "\\", " ", "+", "?"}
end

source.is_available = function(self)
  -- client is stopped.
  if self.client.is_stopped() then
    return false
  end
  -- client is not attached to current buffer.
  if not vim.lsp.buf_get_clients(vim.api.nvim_get_current_buf())[self.client.id] then
    return false
  end
  if not self.client.name == "copilot" then
    return false
  end
  return true
end

source.deindent = function(_, text)
  local indent = string.match(text, '^%s*')
  if not indent then
    return text
  end
  return string.gsub(string.gsub(text, '^' .. indent, ''), '\n' .. indent, '\n')
end

local function get_last_i_chars(string, i)
  return string.sub(string, #string-i, #string)
end

local function get_first_i_chars(string, i)
  return string.sub(string, 1, i)
end

source.remove_entry_end = function(line, entry, index, thisline)
  local linefunc = get_last_i_chars
  local entryfunc = get_last_i_chars
  if linefunc(line, index) == entryfunc(entry, index) and index <= string.len(line) and index <= string.len(entry) then
    return source.remove_entry_end(line, entry, index+1, thisline)
  elseif index >= 1 then
    return get_first_i_chars(entry, #entry-index)
  else
    return entry
  end
end
source.clean_entry = function (deindented)
  local nextline = vim.api.nvim_win_get_cursor(0)[1]
  deindented = string.gsub(deindented, '\n$', '')
  local thisline = true
  if string.find(deindented, "\n") then
    thisline = false
  end
  local linenr = thisline and nextline - 1 or nextline
  local line = vim.api.nvim_buf_get_lines(0, linenr, linenr+1, false)[1]
  local cleaned = source.remove_entry_end(line, deindented, 0, thisline)
  cleaned = string.gsub(cleaned, '\n$', '')
  return cleaned
end

local deindent_insertion = function(text)
  local indent = string.match(text, '^%s*')
  if not indent then
    return text
  end
  return string.gsub(text, '^' .. indent, '')
end

source.get_range = function (item, params)
  return {
    start = item.range.start,
    ['end'] = params.context.cursor,
  }
end

local format_and_clean_insertion = function(item, params)
  local deindented = deindent_insertion(item.text)
  deindented = source.clean_entry(deindented)
  return {
    range = source.get_range(item, params),
    newText = deindented
  }
end

source.format_completions = function(self, params, completions)
  local formatted = {
    IsIncomplete = true,
    items = vim.tbl_map(function(item)
      item = vim.tbl_extend('force', {}, item)
      local cleaned = self:deindent(item.text)
      return {
        label = cleaned,
        kind = 15,
        textEdit = format_and_clean_insertion(item, params),
        documentation = {
          kind = "markdown",
          value = "```" .. vim.bo.filetype .. "\n" .. cleaned .. "\n```"
        },
      }
    end, completions)
  }
  return formatted
end

source.complete = function(self, params, callback)
  existing_matches[params.context.bufnr] = existing_matches[params.context.bufnr] or {}
  existing_matches[params.context.bufnr][params.context.cursor.row] = existing_matches[params.context.bufnr][params.context.cursor.row] or { IsIncomplete = true }
  local existing = existing_matches[params.context.bufnr][params.context.cursor.row]
  local has_complete = false
  vim.lsp.buf_request(0, "getCompletionsCycling", util.get_completion_params(), function(_, response)
    if response and not vim.tbl_isempty(response.completions) then
      existing = vim.tbl_deep_extend("force", existing, self:format_completions(params, response.completions))
      has_complete = true
    end
    vim.schedule(function() callback(existing) end)
  end)
  if not has_complete then
    callback(existing)
  end
end

return source
