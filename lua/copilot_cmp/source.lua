local source = {}

function source:get_keyword_pattern()
  return "\\w\\+.*"
end

source.get_trigger_characters = function()
  return { "\t", "\n", ".", ":", "(", "'", '"', "[", ",", "#", "*", "@", "|", "=", "-", "{", "/", "\\", " ", "+", "?"}
end

source.autofmt = function (_, completion_item, callback)
  vim.schedule(function ()
    local fmt_info = completion_item.fmt_info
    vim.api.nvim_win_set_cursor(0, {fmt_info.startl, 0})
    vim.cmd("silent! normal " .. tostring(fmt_info.n_lines) .. "==")
    local endl_contents = vim.api.nvim_buf_get_lines(0, fmt_info.endl-1, fmt_info.endl+1, false)[1] or ""
    vim.api.nvim_win_set_cursor(0, {fmt_info.endl, #endl_contents})
  end)
  return callback()
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
local defaults =  {
  method = "getCompletionsCycling",
  force_autofmt = false,
  formatters = {
    label = require("copilot_cmp.format").format_label_text,
    insert_text = require("copilot_cmp.format").format_insert_text,
    preview = require("copilot_cmp.format").deindent,
  },
}

source.new = function(client, opts)
  opts = vim.tbl_deep_extend('force', defaults, opts or {})
  local completion_fn = opts.completion_fn

  local completion_functions = require("copilot_cmp.completion_functions")
  local self = setmetatable({ timer = vim.loop.new_timer() }, { __index = source })

  self.execute = opts.autofmt and source.autofmt or nil
  self.client = client
  self.request_ids = {}

  self.formatters = vim.tbl_deep_extend("force", {}, opts.formatters or {})
  if not self.formatters.label then
    self.formatters.label = require("copilot_cmp.format").format_label_text
  end
  if not self.formatters.insert_text then
    self.formatters.insert_text = require("copilot_cmp.format").format_insert_text
  end
  if not self.formatters.preview then
    self.formatters.preview = require("copilot_cmp.format").deindent
  end

  self.complete = completion_fn and completion_functions.init(completion_fn) or completion_functions.init("getCompletionsCycling")

  return self
end

return source
