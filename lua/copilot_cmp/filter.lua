-- -- entry filter for hiding outdated completions
--
-- local {
--     name = 'nvim_lsp',
--     entry_filter = function(entry, ctx)
--       return require('cmp.types').lsp.CompletionItemKind[entry:get_kind()] ~= 'Text'
--     end
--   }
-- <
--
