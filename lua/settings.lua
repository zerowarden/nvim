local vim = vim
local g = vim.g
local opt = vim.opt
local map = vim.keymap.set

g.mapleader = ","
g.maplocalleader = ","

opt.expandtab = true
opt.shiftwidth = 2
opt.softtabstop = 2
opt.tabstop = 2
opt.synmaxcol = 200

opt.autocomplete = true
opt.background = "dark"
opt.breakindent = true
opt.clipboard = "unnamedplus"
opt.complete = "o"
opt.completeopt = "menuone,noselect,popup,fuzzy"
opt.confirm = true
opt.cursorline = true
opt.cursorlineopt = "number"
opt.ignorecase = true
opt.inccommand = "split"
opt.laststatus = 3
opt.mouse = "n"
opt.number = true
opt.pumborder = "rounded"
opt.pumheight = 12
opt.pummaxwidth = 80
opt.scrolloff = 4
opt.showbreak = "↪"
opt.signcolumn = "yes"
opt.smartcase = true
opt.splitbelow = true
opt.splitkeep = "screen"
opt.splitright = true
opt.statusline = " %f %m%r%=%y  %l:%c  %p%% "
opt.termguicolors = true
opt.undofile = true
opt.virtualedit = "block"
opt.winborder = "rounded"

map("i", "jk", "<Esc>")
map("i", "<C-Space>", function()
  vim.lsp.completion.get()
end, { desc = "LSP completion" })
map("i", "<C-y>", function()
  if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected == -1 then
    return "<C-n><C-y>"
  end
  return "<C-y>"
end, { expr = true, replace_keycodes = true, desc = "Accept completion" })
map("n", ";", ":")
map("n", "j", "gj", { noremap = true })
map("n", "<leader><space>", ':let @/=""<CR>', { silent = true })

vim.filetype.add({
  extension = {
    hcl = "hcl",
    tf = "terraform",
    tfvars = "terraform",
  },
  filename = {
    [".terraformrc"] = "hcl",
    ["terraform.rc"] = "hcl",
  },
  pattern = {
    [".*%.tfstate"] = "json",
    [".*%.tfstate%.backup"] = "json",
  },
})
