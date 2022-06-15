# copilot-cmp

This repository transforms https://github.com/zbirenbaum/copilot.lua into a cmp source.

Copilot suggestions will automatically be loaded into your cmp menu as snippets and display their full contents when a copilot suggestion is hovered.

![copilot-cmp](https://user-images.githubusercontent.com/32016110/161629472-db4324f1-d091-441c-a681-d3d9b589ecd0.png)

## Setup

If you already have copilot.lua installed, you can install this plugin with packer as you would any other with the following code:

### Install

```lua
use {
  "zbirenbaum/copilot-cmp",
  module = "copilot_cmp",
},
```

If you do not have copilot.lua installed, go to https://github.com/zbirenbaum/copilot.lua and follow the instructions there before installing this one

### Configuration

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

##### Highlighting

You can create a custom entry label and highlight group for copilot completions similar to those for different Lsp kinds by modifying the format function of your cmp config. By default, copilot entries will appear with the `Snippet` label and highlight

Example:

```lua
cmp.setup {
  ...
  formatting = {
    format = function (entry, vim_item)
      if entry.source.name == "copilot" then
        vim_item.kind = "[] Copilot"
        vim_item.kind_hl_group = "CmpItemKindCopilot"
        return vim_item
      end
      return lspkind.cmp_format({ with_text = false, maxwidth = 50 })(entry, vim_item)
    end
  }
  ...
}

vim.api.nvim_set_hl(0, "CmpItemKindCopilot", {fg ="#6CC644"})
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
