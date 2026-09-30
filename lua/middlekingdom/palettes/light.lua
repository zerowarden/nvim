-- lua/middlekingdom/palettes/light.lua: TEMPLATE for your light variant.
-- It starts as a copy of andromeda so its keys match what groups.lua references.
-- The names are roles, not hues (exact keys depend on your sonokai version):
--   bg0              editor background
--   bg1 .. bg4       surfaces stepping progressively away from bg0
--                    (cursor line, popups, selection, status line)
--   bg_dim, black    lower-emphasis surfaces
--   fg, grey, grey_dim  text at decreasing emphasis
--   red .. purple    accents; keep them legible on bg0 and on bg1..bg4
--   bg_*, diff_*     tinted backgrounds for diagnostics and diffs
-- Derived from sainnhe/sonokai (MIT License, Copyright (c) sainnhe).
return {
  _template = true, -- delete this line once the palette is designed
  black = "#181a1c",
  bg_dim = "#252630",
  bg0 = "#2b2d3a",
  bg1 = "#333648",
  bg2 = "#363a4e",
  bg3 = "#393e53",
  bg4 = "#3f445b",
  fg = "#e1e3e4",
  red = "#fb617e",
  orange = "#f89860",
  yellow = "#edc763",
  green = "#9ed06c",
  blue = "#6dcae8",
  purple = "#bb97ee",
  grey = "#7e8294",
  grey_dim = "#5a5e7a",
  bg_blue = "#354157",
  bg_green = "#394634",
  bg_purple = "#423f59",
  bg_red = "#55393d",
  bg_yellow = "#4e432f",
  filled_blue = "#77d5f0",
  filled_green = "#a9dc76",
  filled_red = "#ff6188",
}
