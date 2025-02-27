-- scaffolder.lua
-- Global setup

if vim.g.loaded_scaffolder == 1 then
  return
end
vim.g.loaded_scaffolder = 1

require('scaffolder').setup({})