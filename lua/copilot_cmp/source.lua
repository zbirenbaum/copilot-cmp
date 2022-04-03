local source = {}
local util = require("copilot.util")

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
   return 'copilot'
end

source.get_trigger_characters = function(self)
   return self:_get(self.client.server_capabilities, { 'completionProvider', 'triggerCharacters' }) or {}
end

source.is_available = function(self)
   -- client is stopped.
   if self.client.is_stopped() then return false end
   -- client is not attached to current buffer.
   if not vim.lsp.buf_get_clients(vim.api.nvim_get_current_buf())[self.client.id] then
      return false
   end
   if not self.client.name == "copilot" then
      return false
   end
   return true;
end

source.resolve = function(self, completion_item, callback)
   if self.client.is_stopped() then
      return callback()
   end

   -- client has no completion capability.
   if not self:_get(self.client.server_capabilities, { 'completionProvider', 'resolveProvider' }) then
      return callback()
   end

   self:_request('completionItem/resolve', completion_item, function(_, response)
      callback(response or completion_item)
   end)
end

source.execute = function(self, completion_item, callback)
   -- client is stopped.
   if self.client.is_stopped() then
      return callback()
   end

   -- completion_item has no command.
   if not completion_item.command then
      return callback()
   end

   self:_request('workspace/executeCommand', completion_item.command, function(_, _)
      callback()
   end)
end

local format_response = function (response)
   if not response or vim.tbl_isempty(response.completions) then return response end
   local completion = response.completions[1]
   local formatted = {}
   formatted.label = string.gsub(completion.text, '^%s*(.-)%s*$', '%1')
   formatted.textEdit = {}
   formatted.textEdit.newText = string.gsub(completion.text, '^%s*(.-)%s*$', '%1')
   formatted.textEdit.range = completion.range
   formatted.textEdit.range["end"].line = formatted.textEdit.range["end"].line + 1
   formatted.textEdit.range["start"].line = formatted.textEdit.range["start"].line + 1
   return formatted
end

source.complete = function(self, request, callback)
   local get_completions = function(params)
      vim.lsp.buf_request(0, 'getCompletions', params, function(_, response)
         local formatted = format_response(response)
         callback({formatted})
      end)
   end
   local params = util.get_completion_params()
   get_completions(params)
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
