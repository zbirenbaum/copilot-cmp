# copilot-cmp

This repository transforms https://github.com/zbirenbaum/copilot.lua into a cmp source.

Copilot suggestions will automatically be loaded into your cmp menu as snippets and display their full contents when a copilot suggestion is hovered.

![copilot-cmp](https://user-images.githubusercontent.com/32016110/173933674-9ad85a5a-5ad7-41cd-9fcc-f5a698cc88ae.png)


## Setup

If you already have copilot.lua installed, you can install this plugin with packer as you would any other with the following code:

### Install

```lua
use {
  "zbirenbaum/copilot-cmp",
  after = { "copilot.lua" },
  config = function ()
    require("copilot_cmp").setup()
  end
}
```

If you do not have copilot.lua installed, go to https://github.com/zbirenbaum/copilot.lua and follow the instructions there before installing this one

### Configuration

##### Default Options:
These are the default options for copilot-cmp which can be configured via the setup function:
```lua
{
  method = "getCompletionsCycling",
  force_autofmt = false,
  clear_after_cursor = true,
  formatters = {
    label = require("copilot_cmp.format").format_label_text,
    insert_text = require("copilot_cmp.format").format_insert_text,
    preview = require("copilot_cmp.format").deindent,
  },
}
```

##### method

Set the `method` field to `getCompletionsCycling` if you are having issues. getPanelCompletions previously worked just as quickly, and did not limit completions in the cmp menu to 3 recommendations, but has become so slow completions do not seem to appear due to recent changes from Microsoft. getPanelCompletions also allows for the comparator provided in copilot-cmp to not just place all copilot completions on top, but also sort them by the `score` copilot assigns them, which is not provided by getCompletionsCycling. Example:

```lua
-- Recommended
require("copilot_cmp").setup {
  method = "getCompletionsCycling",
}
```

```lua
-- Not Currently Recommended
require("copilot_cmp").setup {
  method = "getPanelCompletions",
}
```

##### force_autofmt
this option will cause the insertions to be formatted using the vim format function (e.g.`gg=G`) after every insertion

##### clear_after_cursor
this option will cause any text on the current line after the cursor to be cleared before inserting new text. It is highly recommended to leave this set to true if you use any sort of autopairs plugin.

##### formatters
The `label` field corresponds to the function returning the label of the entry in nvim-cmp, `insert_text` corresponds to the actual text that is inserted, and `preview` corresponds to the text shown in the documentation window when hovering the completion.

There is an experimental method for attempting to remove extraneous characters such as extra ending parenthesis that appears to work fairly well. If you wish to use it, simply place the following in your setup function:
```lua
{
  formatters = {
    insert_text = require("copilot_cmp.format").remove_existing
  },
}


```
Additionally, each field can be overriden by a user function that takes (item, ctx) as parameters and should return a string representing what you wish to supply cmp. This is an advanced feature to provide maximum configurability for how the source will format the raw output from Copilot. These functions can be extremely complex, and this is feature only recommended for advanced users, so taking a look at how the default functions work inside of `format.lua` will likely be necessary if you wish to override the behavior.
##### Source Definition

To link cmp with this source, simply go into your cmp configuration file and include `{ name = "copilot" }` under your sources

Here is an example of what it should look like:

```lua
cmp.setup {
  ...
  sources = {
    -- Copilot Source
    { name = "copilot", group_index = 2 },
    -- Other Sources
    { name = "nvim_lsp", group_index = 2 },
    { name = "path", group_index = 2 },
    { name = "luasnip", group_index = 2 },
  },
  ...
}
```

##### Highlighting & Icon

Copilot's cmp source now has a builtin highlight group `CmpItemKindCopilot`. To add an icon to copilot for lspkind, simply add copilot to your lspkind symbol map.

```lua
-- lspkind.lua
local lspkind = require("lspkind")
lspkind.init({
  symbol_map = {
    Copilot = "",
  },
}

vim.api.nvim_set_hl(0, "CmpItemKindCopilot", {fg ="#6CC644"})
```

Alternatively, you can add Copilot to the lspkind `symbol_map` within the cmp format function.

```lua
-- cmp.lua
cmp.setup {
  ...
  formatting = {
    format = lspkind.cmp_format({
      mode = "symbol",
      max_width = 50,
      symbol_map = { Copilot = "" }
    })
  }
  ...
}
```

If you do not use lspkind, simply add the custom icon however you normally handle `kind` formatting and it will integrate as if it was any other normal lsp completion kind.

##### Tab Completion Configuration (Highly Recommended)
Unlike other completion sources, copilot can use other lines above or below an empty line to provide a completion. This can cause problematic for individuals that select menu entries with `<TAB>`. This behavior is configurable via cmp's config and the following code will make it so that the menu still appears normally, but tab will fallback to indenting unless a non-whitespace character has actually been typed.

```lua
local has_words_before = function()
  if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then return false end
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_text(0, line-1, 0, line-1, col, {})[1]:match("^%s*$") == nil
end
cmp.setup({
  mapping = {
    ["<Tab>"] = vim.schedule_wrap(function(fallback)
      if cmp.visible() and has_words_before() then
        cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
      else
        fallback()
      end
    end),
  },
})
```

##### Comparators

Two customs comparitors for sorting cmp entries are provided: `score` and `prioritize`. The `prioritize` comparitor causes copilot entries to appearhigher in the cmp menu. The `score` comparitor only does something if getPanelCompletions is the method used in the cmp field of the copilot.lua config. It is recommended keeping priority weight at 2, or placing the `exact` comparitor above copilot so that better lsp matches are not stuck below poor copilot matches.

Example:

```lua
cmp.setup {
  ...
  sorting = {
    priority_weight = 2,
    comparators = {
      require("copilot_cmp.comparators").prioritize,
      require("copilot_cmp.comparators").score,

      -- Below is the default comparitor list and order for nvim-cmp
      cmp.config.compare.offset,
      -- cmp.config.compare.scopes, --this is commented in nvim-cmp too
      cmp.config.compare.exact,
      cmp.config.compare.score,
      cmp.config.compare.recently_used,
      cmp.config.compare.locality,
      cmp.config.compare.kind,
      cmp.config.compare.sort_text,
      cmp.config.compare.length,
      cmp.config.compare.order,
    },
  },
  ...
}
```
