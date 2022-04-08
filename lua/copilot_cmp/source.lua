local source = {}
local util = require("copilot.util")
local existing_matches = {}

source.new = function(client)
  local self = setmetatable({}, { __index = source })
  self.client = client
  self.request_ids = {}
  return self
end

local function find_copilot()
  local clients = vim.tbl_deep_extend(
    vim.lsp.buf_get_clients(vim.api.nvim_get_current_buf()),
    vim.lsp.get_active_clients()
  )
  for client in ipairs(clients) do
    if client.name == "copilot" then
      return client
    end
  end
end

source.get_debug_name = function(self)
  return "copilot"
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

source.format_completions = function(self, params, completions)
  local formatted = {
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
          newText = cleaned,
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
  local handler = function(_, response)
    local formatted = {}
    if response and not vim.tbl_isempty(response.completions) then
      formatted = self:format_completions(params, response.completions)
    end
    callback(formatted)
  end
  vim.lsp.buf_request(0, "getCompletionsCycling", util.get_completion_params(), handler)
end

source._get = function(_, root, paths)
  local c = root
  for _, path in ipairs(paths) do
    c = c[path]
    if not c then
      return nil
    end
  end
  return c
end

source._request = function(self, method, params, callback)
  if self.request_ids[method] ~= nil then
    self.client.cancel_request(self.request_ids[method])
    self.request_ids[method] = nil
  end
  local _, request_id
  _, request_id = self.client.request(method, params, function(arg1, arg2, arg3)
    if self.request_ids[method] ~= request_id then
      return
    end
    self.request_ids[method] = nil

    -- Text changed, retry
    if arg1 and arg1.code == -32801 then
      self:_request(method, params, callback)
      return
    end

    if method == arg2 then
      callback(arg1, arg3) -- old signature
    else
      callback(arg1, arg2) -- new signature
    end
  end)
  self.request_ids[method] = request_id
end

return source
