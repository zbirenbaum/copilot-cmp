local source = {}
local util = require("copilot.util")
local existing_matches = {}

source.new = function(client)
  local self = setmetatable({ timer = vim.loop.new_timer() }, { __index = source })
  self.client = client
  self.request_ids = {}
  return self
end

source.get_trigger_characters = function(self)
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

source.deindent_insertion = function(_, text)
  local indent = string.match(text, '^%s*')
  if not indent then
    return text
  end
  return string.gsub(text, '^' .. indent, '')
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
        textEdit = {
          range = {
            start = item.range.start,
            ['end'] = params.context.cursor,
          },
          newText = self:deindent_insertion(item.text)
        },
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
