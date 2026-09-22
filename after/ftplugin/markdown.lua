if vim.api.nvim_buf_line_count(0) > 5000 then
  return
end

local ok, parser = pcall(vim.treesitter.get_parser, 0, "markdown")
if ok and parser then
  pcall(parser.parse, parser, true)
end
