local M = {}

M.get_client = vim.lsp.get_clients or vim.lsp.get_active_clients

return M
