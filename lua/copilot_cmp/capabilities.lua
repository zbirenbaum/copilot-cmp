-- credits to hrsh7th/cmp-nvim-lsp
-- https://raw.githubusercontent.com/hrsh7th/cmp-nvim-lsp/main/lua/cmp_nvim_lsp/init.lua

local M = {}

local if_nil = function(val, default)
  if val == nil then
    return default
  end
  return val
end

-- Backported from vim.deprecate (0.9.0+)
local function deprecate(name, alternative, version, plugin, backtrace)
  local message = name .. " is deprecated"
  plugin = plugin or "Nvim"
  message = alternative and (message .. ", use " .. alternative .. " instead.") or message
  message = message .. " See :h deprecated\nThis function will be removed in " .. plugin .. " version " .. version
  if vim.notify_once(message, vim.log.levels.WARN) and backtrace ~= false then
    vim.notify(debug.traceback("", 2):sub(2), vim.log.levels.WARN)
  end
end

M.default_capabilities = function(override)
  override = override or {}

  return {
    textDocument = {
      completion = {
        dynamicRegistration = if_nil(override.dynamicRegistration, false),
        completionItem = {
          snippetSupport = if_nil(override.snippetSupport, true),
          commitCharactersSupport = if_nil(override.commitCharactersSupport, true),
          deprecatedSupport = if_nil(override.deprecatedSupport, true),
          preselectSupport = if_nil(override.preselectSupport, true),
          tagSupport = if_nil(override.tagSupport, {
            valueSet = {
              1, -- Deprecated
            },
          }),
          insertReplaceSupport = if_nil(override.insertReplaceSupport, true),
          resolveSupport = if_nil(override.resolveSupport, {
            properties = {
              "documentation",
              "detail",
              "additionalTextEdits",
            },
          }),
          insertTextModeSupport = if_nil(override.insertTextModeSupport, {
            valueSet = {
              1, -- asIs
              2, -- adjustIndentation
            },
          }),
          labelDetailsSupport = if_nil(override.labelDetailsSupport, true),
        },
        contextSupport = if_nil(override.snippetSupport, true),
        insertTextMode = if_nil(override.insertTextMode, 1),
        completionList = if_nil(override.completionList, {
          itemDefaults = {
            "commitCharacters",
            "editRange",
            "insertTextFormat",
            "insertTextMode",
            "data",
          },
        }),
      },
    },
  }
end

---Backwards compatibility
M.update_capabilities = function(_, override)
  local _deprecate = vim.deprecate or deprecate
  _deprecate("copilot_cmp.update_capabilities", "copilot_cmp.default_capabilities", "1.0.0", "copilot_cmp")
  return M.default_capabilities(override)
end

return M
