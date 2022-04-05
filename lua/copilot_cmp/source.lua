local source = {}
local util = require("copilot.util")
local existing_matches={}

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

local check_match = function (list)
   if vim.tbl_isempty(list) then return list end
   local linenr = vim.api.nvim_win_get_cursor(0)[1]
   local curline = vim.api.nvim_buf_get_lines(0, linenr - 1, linenr, false)[1]
   if curline == "" then list = {} return list end
   for index, completion in ipairs(list) do
      list[index] = string.find(string.gsub(completion.textEdit.newText, '%[%]', ''), string.gsub(curline, '%[%]', '')) and completion or nil
   end
   return list
end

local format_response = function (response)
   if not response or vim.tbl_isempty(response.completions) then return {} end
   local formatted_completions = {}
   for _ , completion in ipairs(response.completions) do
      local cleaned = string.gsub(completion.text, '^%s*(.-)%s*$', '%1')
      local formatted = {
         label = cleaned,
         kind = 15,
         textEdit = {
            newText = cleaned,
            range = {
               start = {
                  line = completion.range.start.line+1,
                  character = completion.range.start.character
               },
               ["end"] = {
                  line = completion.range["end"].line+1,
                  character = completion.range["end"].character
               }
            }
         },
         documentation = {kind="markdown", value = "```lua\n" .. cleaned .. "\n```"}
      }
      table.insert(formatted_completions, formatted)
   end
   return formatted_completions
end

local merge_existing = function (list_a, list_b)
   if not list_a or vim.tbl_isempty(list_a) then
      return list_b, list_b
   end
   for index, completion in ipairs(list_a) do
      for index_b, new_completion in ipairs(list_b) do
         if completion.textEdit.newText == new_completion.textEdit.newText then
            list_a[index] = new_completion
            list_b[index_b] = nil
         end
      end
   end
   return list_a,list_b
end


source.complete = function(_, _, callback)
   local handler = function(_, response)
      local linenr = vim.api.nvim_win_get_cursor(0)[1]
      local formatted_completions = format_response(response)
      if not existing_matches[linenr] then
         existing_matches[linenr] = {}
         if formatted_completions and formatted_completions ~= {} then
            existing_matches[linenr] = vim.tbl_deep_extend("force", existing_matches[linenr], formatted_completions)
         end
      else
         existing_matches[linenr] = check_match(existing_matches[linenr])
         existing_matches[linenr] = merge_existing(existing_matches[linenr], formatted_completions)
      end
      callback(existing_matches[linenr])
   end
   local get_completions = function(params)
      vim.lsp.buf_request(0, 'getCyclingCompletions', params, handler)
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
