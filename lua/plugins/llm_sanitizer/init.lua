local utf8 = _G.utf8
if not utf8 then
  utf8 = {}
  function utf8.char(cp)
    return vim.fn.nr2char(cp)
  end

  -- Iterator: yields (byte_index, codepoint) to mimic Lua 5.3
  function utf8.codes(s)
    local i, len = 1, #s
    return function()
      if i > len then
        return nil
      end
      local b1 = string.byte(s, i)
      if not b1 then
        return nil
      end
      local cp, nbytes
      if b1 < 0x80 then
        cp, nbytes = b1, 1
      elseif b1 < 0xE0 then
        local b2 = string.byte(s, i + 1) or 0
        cp = ((b1 % 0x20) * 0x40) + (b2 % 0x40)
        nbytes = 2
      elseif b1 < 0xF0 then
        local b2 = string.byte(s, i + 1) or 0
        local b3 = string.byte(s, i + 2) or 0
        cp = ((b1 % 0x10) * 0x1000) + ((b2 % 0x40) * 0x40) + (b3 % 0x40)
        nbytes = 3
      else
        local b2 = string.byte(s, i + 1) or 0
        local b3 = string.byte(s, i + 2) or 0
        local b4 = string.byte(s, i + 3) or 0
        cp = ((b1 % 0x08) * 0x40000) + ((b2 % 0x40) * 0x1000) + ((b3 % 0x40) * 0x40) + (b4 % 0x40)
        nbytes = 4
      end
      local pos = i
      i = i + nbytes
      return pos, cp
    end
  end
end

local M = {}
local api, fn, tbl_extend = vim.api, vim.fn, vim.tbl_deep_extend

-- Single UTF-8 codepoint pattern (bytewise) for Lua patterns
local UTF8_CHAR_PATTERN = "[%z\1-\127\194-\244][\128-\191]*"

-- Byte pattern for U+E0000-U+E007F (Tag characters), encoded in UTF-8:
--  F3 A0 [80-81] [80-BF]
local TAG_UTF8_PATTERN = (function()
  local ch = string.char
  return ch(0xF3)
    .. ch(0xA0)
    .. "["
    .. ch(0x80)
    .. "-"
    .. ch(0x81)
    .. "]"
    .. "["
    .. ch(0x80)
    .. "-"
    .. ch(0xBF)
    .. "]"
end)()

local default_config = {
  replacements = {
    -- Zero-width / invisible
    [fn.nr2char(0x200B)] = "", -- ZERO WIDTH SPACE
    [fn.nr2char(0x200C)] = "", -- ZERO WIDTH NON-JOINER
    [fn.nr2char(0x200D)] = "", -- ZERO WIDTH JOINER
    [fn.nr2char(0xFEFF)] = "", -- ZERO WIDTH NO-BREAK SPACE (BOM)
    [fn.nr2char(0xFFFC)] = "", -- OBJECT REPLACEMENT CHARACTER
    [fn.nr2char(0x2060)] = "", -- WORD JOINER

    -- Directional marks (BiDi control characters)
    [fn.nr2char(0x200E)] = "", -- LEFT-TO-RIGHT MARK (LRM)
    [fn.nr2char(0x200F)] = "", -- RIGHT-TO-LEFT MARK (RLM)
    [fn.nr2char(0x202A)] = "", -- LEFT-TO-RIGHT EMBEDDING (LRE)
    [fn.nr2char(0x202B)] = "", -- RIGHT-TO-LEFT EMBEDDING (RLE)
    [fn.nr2char(0x202C)] = "", -- POP DIRECTIONAL FORMATTING (PDF)
    [fn.nr2char(0x202D)] = "", -- LEFT-TO-RIGHT OVERRIDE (LRO)
    [fn.nr2char(0x202E)] = "", -- RIGHT-TO-LEFT OVERRIDE (RLO)
    [fn.nr2char(0x2066)] = "", -- LEFT-TO-RIGHT ISOLATE (LRI)
    [fn.nr2char(0x2067)] = "", -- RIGHT-TO-LEFT ISOLATE (RLI)
    [fn.nr2char(0x2068)] = "", -- FIRST STRONG ISOLATE (FSI)
    [fn.nr2char(0x2069)] = "", -- POP DIRECTIONAL ISOLATE (PDI)

    -- Spaces -> regular space
    [fn.nr2char(0x00A0)] = " ",
    [fn.nr2char(0x202F)] = " ",
    [fn.nr2char(0x200A)] = " ",
    [fn.nr2char(0x2009)] = " ",
    [fn.nr2char(0x2008)] = " ",
    [fn.nr2char(0x2002)] = " ",
    [fn.nr2char(0x2003)] = " ",

    -- Hyphens and dashes
    [fn.nr2char(0x2011)] = "-",
    [fn.nr2char(0x2010)] = "-",
    [fn.nr2char(0x2012)] = "-",
    [fn.nr2char(0x2013)] = "-",
    [fn.nr2char(0x2014)] = "-",
    [fn.nr2char(0x2212)] = "-",

    -- Quotes
    [fn.nr2char(0x2018)] = "'",
    [fn.nr2char(0x2019)] = "'",
    [fn.nr2char(0x201C)] = '"',
    [fn.nr2char(0x201D)] = '"',
    [fn.nr2char(0x2039)] = "'",
    [fn.nr2char(0x203A)] = "'",
    [fn.nr2char(0x00AB)] = '"',
    [fn.nr2char(0x00BB)] = '"',

    -- Ellipsis
    [fn.nr2char(0x2026)] = "...",

    -- Bullets
    [fn.nr2char(0x2022)] = "*",
    [fn.nr2char(0x2023)] = "-",
    [fn.nr2char(0x2043)] = "-",
    [fn.nr2char(0x2219)] = "*",
    [fn.nr2char(0x00B7)] = "*",

    -- Arrows
    [fn.nr2char(0x2192)] = "->",
    [fn.nr2char(0x2190)] = "<-",
    [fn.nr2char(0x2194)] = "<->",
    [fn.nr2char(0x21A6)] = "->",
    [fn.nr2char(0x21E8)] = "=>",

    -- Math symbols
    [fn.nr2char(0x2264)] = "<=",
    [fn.nr2char(0x2265)] = ">=",
    [fn.nr2char(0x00B1)] = "+/-",
    [fn.nr2char(0x00D7)] = "x",
    [fn.nr2char(0x2217)] = "*",
    [fn.nr2char(0x2212)] = "-",

    -- Misc
    [fn.nr2char(0x2E3B)] = "", -- TWO-EM DASH (rare, often editorial)
    [fn.nr2char(0x2044)] = "/", -- FRACTION SLASH
    [fn.nr2char(0x2016)] = "||", -- DOUBLE VERTICAL LINE
    [fn.nr2char(0x22C5)] = ".", -- DOT OPERATOR

    -- Fullwidth digits -> ASCII digits
    [fn.nr2char(0xFF10)] = "0",
    [fn.nr2char(0xFF11)] = "1",
    [fn.nr2char(0xFF12)] = "2",
    [fn.nr2char(0xFF13)] = "3",
    [fn.nr2char(0xFF14)] = "4",
    [fn.nr2char(0xFF15)] = "5",
    [fn.nr2char(0xFF16)] = "6",
    [fn.nr2char(0xFF17)] = "7",
    [fn.nr2char(0xFF18)] = "8",
    [fn.nr2char(0xFF19)] = "9",
  },

  remove_tag_block = true,
  filetype_whitelist = nil,

  highlight = {
    enabled = true,
    show_virtual_text = true,
    hl_group = "LlmSanitizerSuspect",
    virt_text_hl = "LlmSanitizerVirt",
    namespace = "llm_sanitizer_ns",
  },

  notify_level = vim.log.levels.INFO,
}

local State = {
  config = default_config,
  enabled = true,
  ns = api.nvim_create_namespace(default_config.highlight.namespace),
  highlight_enabled = {},
  repl_cp_set = nil,
}

local function merge_user_config(user_config)
  user_config = user_config or {}
  local merged = tbl_extend("force", default_config, user_config)
  merged.replacements =
    tbl_extend("force", default_config.replacements, user_config.replacements or {})
  return merged
end

-- Build fast lookup of codepoints present in replacements (for highlighting)
local function rebuild_fastsets()
  local set = {}
  for ch, _ in pairs(State.config.replacements) do
    if type(ch) == "string" and #ch > 0 then
      local cp = fn.char2nr(ch)
      if type(cp) == "number" then
        set[cp] = true
      end
    end
  end
  State.repl_cp_set = set
end

-- Efficient tag removal using a single gsub over the whole range.
local function remove_tag_block_from_line(s)
  if not State.config.remove_tag_block then
    return s, 0
  end
  local new, n = s:gsub(TAG_UTF8_PATTERN, "")
  return new, n -- n is number of tag chars removed
end

-- Effective replacements table (merged)
local function effective_replacements()
  return State.config.replacements
end

-- Reusable scratch table helper
local function clear_tbl(t)
  for k in pairs(t) do
    t[k] = nil
  end
end

-- Single-pass sanitizer over codepoints using UTF8_CHAR_PATTERN.
local function sanitize_line(line, scratch_counters)
  local replacements = effective_replacements()
  local counters = scratch_counters or {}
  if scratch_counters then
    clear_tbl(counters)
  end
  local changed = false
  local old = line

  -- Pass 1: map codepoints via lookup (one gsub over the line)
  line = line:gsub(UTF8_CHAR_PATTERN, function(ch)
    local to = replacements[ch]
    if to ~= nil then
      counters[ch] = (counters[ch] or 0) + 1
      changed = true
      return to
    end
    return ch
  end)

  -- Pass 2: remove tag-block range in a single sweep
  local removed_n
  line, removed_n = remove_tag_block_from_line(line)
  if removed_n > 0 then
    counters["<TAG_BLOCK>"] = (counters["<TAG_BLOCK>"] or 0) + removed_n
    changed = true
  end

  local diff = nil
  if changed and line ~= old then
    diff = { before = old, after = line }
  end
  return line, changed, counters, diff
end

local function build_space_set()
  local cps = {
    0x0020,
    0x0009,
    0x00A0,
    0x202F,
    0x200A,
    0x2009,
    0x2008,
    0x2002,
    0x2003,
    0x2007,
  }
  local set = {}
  for _, c in ipairs(cps) do
    set[c] = true
  end
  return set
end

local SPACE_SET = build_space_set()

local function process_range(bufnr, l1, l2, do_replace)
  local lines = api.nvim_buf_get_lines(bufnr, l1 - 1, l2, false)
  local changed_any = false
  local merged_counters, diffs = {}, {}
  local scratch = {} -- reused per line

  for i = 1, #lines do
    local ln = lines[i]
    local newl, changed, counters, diff = sanitize_line(ln, scratch)
    if changed then
      changed_any = true
      for k, v in pairs(counters) do
        merged_counters[k] = (merged_counters[k] or 0) + v
      end
      if diff then
        diffs[#diffs + 1] = { lnum = l1 + i - 1, before = diff.before, after = diff.after }
      end
      if do_replace then
        lines[i] = newl
      end
    end
  end

  if do_replace and changed_any then
    api.nvim_buf_set_lines(bufnr, l1 - 1, l2, false, lines)
  end

  return changed_any, merged_counters, diffs
end

local function counters_to_lines(counters)
  local parts = {}
  for k, v in pairs(counters) do
    local label = k
    if type(k) == "string" and #k == 1 then
      label = string.format("U+%04X (%s)", fn.char2nr(k), k)
    end
    parts[#parts + 1] = string.format("%s: %d", label, v)
  end
  table.sort(parts)
  return parts
end

local function cmd_format(opts)
  local bufnr = api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local wl = State.config.filetype_whitelist
  if wl and #wl > 0 then
    local ok = false
    for _, v in ipairs(wl) do
      if v == ft then
        ok = true
        break
      end
    end
    if not ok then
      vim.notify("LLM Sanitizer: filetype not whitelisted, skipping", State.config.notify_level)
      return
    end
  end

  local l1, l2 = 1, api.nvim_buf_line_count(bufnr)
  if opts and opts.range and opts.range ~= 0 then
    l1, l2 = opts.line1, opts.line2
  end

  local changed, counters, _ = process_range(bufnr, l1, l2, true)
  if not changed then
    vim.notify("FormatLLMOutput: nothing to change", State.config.notify_level)
    return
  end
  local parts = counters_to_lines(counters)
  vim.notify("FormatLLMOutput: cleaned. " .. table.concat(parts, ", "), State.config.notify_level)
end

local function clear_highlights(bufnr)
  api.nvim_buf_clear_namespace(bufnr, State.ns, 0, -1)
end

local function ensure_highlight_groups()
  pcall(
    api.nvim_set_hl,
    0,
    "LlmSanitizerSuspect",
    { bg = "#FFFF00", fg = "#000000", underline = true }
  )
  pcall(api.nvim_set_hl, 0, "LlmSanitizerVirt", { fg = "#FFFF00", bold = true })
end

-- Byte length from codepoint (avoid utf8.char())
local function cp_nbytes(cp)
  if cp < 0x80 then
    return 1
  elseif cp < 0x800 then
    return 2
  elseif cp < 0x10000 then
    return 3
  else
    return 4
  end
end

local function highlight_buffer(bufnr, opts)
  opts = opts or {}
  ensure_highlight_groups()
  clear_highlights(bufnr)

  local ns = State.ns
  local repl_cp_set = State.repl_cp_set or {}

  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for lnum = 1, #lines do
    local line = lines[lnum]
    for pos, cp in utf8.codes(line) do
      local is_suspect = repl_cp_set[cp]
        or (SPACE_SET[cp] and cp ~= 32)
        or (cp >= 0xE0000 and cp <= 0xE007F)

      if is_suspect then
        local nb = cp_nbytes(cp)
        api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, pos - 1, {
          end_col = (pos - 1) + nb,
          hl_group = State.config.highlight.hl_group,
        })
        if State.config.highlight.show_virtual_text then
          local label = string.format("[%04X]", cp)
          api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, pos - 1, {
            virt_text = { { label, State.config.highlight.virt_text_hl } },
            virt_text_pos = "right_align",
            hl_mode = "combine",
          })
        end
      end
    end
  end
end

local function cmd_highlight_show()
  local bufnr = api.nvim_get_current_buf()
  if not State.config.highlight.enabled then
    vim.notify("Highlighting disabled in config", State.config.notify_level)
    return
  end
  State.highlight_enabled[bufnr] = true
  highlight_buffer(bufnr)
  vim.notify("LLM Sanitizer: highlights shown", State.config.notify_level)
end

local function cmd_highlight_clear()
  local bufnr = api.nvim_get_current_buf()
  clear_highlights(bufnr)
  State.highlight_enabled[bufnr] = nil
  vim.notify("LLM Sanitizer: highlights cleared", State.config.notify_level)
end

local function cmd_highlight_toggle()
  local bufnr = api.nvim_get_current_buf()
  if State.highlight_enabled[bufnr] then
    cmd_highlight_clear()
  else
    cmd_highlight_show()
  end
end

function M.setup(user_config)
  State.config = merge_user_config(user_config)
  State.ns = api.nvim_create_namespace(State.config.highlight.namespace)
  rebuild_fastsets()

  local group = api.nvim_create_augroup("LlmSanitizer", { clear = true })

  api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      State.highlight_enabled[args.buf] = nil
    end,
  })

  api.nvim_create_user_command("FormatLLMOutput", function(opts)
    cmd_format(opts)
  end, { range = true })
  api.nvim_create_user_command("LLMSanitizerHighlightShow", function()
    cmd_highlight_show()
  end, {})
  api.nvim_create_user_command("LLMSanitizerHighlightClear", function()
    cmd_highlight_clear()
  end, {})
  api.nvim_create_user_command("LLMSanitizerHighlightToggle", function()
    cmd_highlight_toggle()
  end, {})

  vim.keymap.set(
    "n",
    "<leader>ls",
    cmd_highlight_toggle,
    { desc = "Toggle LLM Sanitizer highlights" }
  )
  vim.keymap.set("n", "<leader>lf", cmd_format, { desc = "Format LLM output" })
end

-- Keep this exported for benchmarks/tests
M.process_range = process_range

return M
