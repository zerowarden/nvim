local vim = vim
local g = vim.g
local opt = vim.opt
local map = vim.keymap.set
local fn = vim.fn
local fs = vim.fs

local state_dir = fn.stdpath("state")
local backup_dir = fs.joinpath(state_dir, "backup")
local swap_dir = fs.joinpath(state_dir, "swap")

fn.mkdir(backup_dir, "p")
fn.mkdir(swap_dir, "p")

g.mapleader = ","
g.maplocalleader = ","

opt.autoindent = true
opt.expandtab = true
opt.shiftwidth = 2
opt.softtabstop = 2
opt.tabstop = 2
opt.synmaxcol = 200

opt.autoread = true
opt.background = "dark"
opt.backupdir = backup_dir
opt.breakindent = true
opt.clipboard = "unnamedplus"
opt.cmdheight = 1
opt.confirm = true
opt.cursorline = true
opt.directory = swap_dir
opt.hidden = true
opt.ignorecase = true
opt.inccommand = "split"
opt.laststatus = 3
opt.mouse = "n"
opt.number = true
opt.scrolloff = 4
opt.showbreak = "↪"
opt.showmatch = true
opt.signcolumn = "yes"
opt.smartcase = true
opt.splitbelow = true
opt.splitkeep = "screen"
opt.splitright = true
opt.undofile = true
opt.virtualedit = "block"

map("i", "jk", "<Esc>")
map("n", "s", "<Plug>(leap)")
map("n", "S", "<Plug>(leap-backward)")
map("n", ";", ":")
map("n", "j", "gj", { noremap = true })
map("n", "<leader><space>", ':let @/=""<CR>', { silent = true })

local indentation_group = vim.api.nvim_create_augroup("IndentationSettings", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = indentation_group,
  pattern = {
    "astro",
    "vue",
    "swift",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "svelte",
    "lua",
    "jsonc",
    "json",
    "html",
    "css",
  },
  callback = function()
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
    vim.bo.expandtab = true
  end,
})

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
