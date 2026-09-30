local M = {}

M.options = {
  -- true/false, or per 'background': { dark = true, light = false }
  transparent = { dark = true, light = false },
  italic = true,
  -- palette module used for each value of 'background'
  variants = { dark = "dark", light = "light" },
}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

function M.load()
  local o = M.options
  local bg = vim.o.background
  local variant = o.variants[bg] or o.variants.dark
  local p = require("middlekingdom.palettes." .. variant)
  if p._template then
    vim.notify(("middlekingdom: palette '%s' is still the unedited template"):format(variant),
      vim.log.levels.WARN)
  end

  local transparent = o.transparent
  if type(transparent) == "table" then transparent = transparent[bg] end
  local ro = vim.tbl_extend("force", o, { transparent = transparent and true or false })

  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
  vim.g.colors_name = "middlekingdom"

  local spec = require("middlekingdom.groups")(p, ro)
  for group, hl in pairs(spec.groups) do
    if not ro.italic and hl.italic then
      hl = vim.tbl_extend("force", hl, { italic = false })
    end
    vim.api.nvim_set_hl(0, group, hl)
  end
  for i = 0, 15 do
    vim.g["terminal_color_" .. i] = spec.terminal[i]
  end
end

return M
