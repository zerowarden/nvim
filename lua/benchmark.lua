-- benchmark.lua
local api = vim.api
local loop = vim.loop

-- require your plugin module (adjust path if necessary)
local sanitizer = require("plugins.llm_sanitizer")

-- helper: generate plain ASCII text with some suspicious chars mixed in
local function generate_test_text(n)
  local lines = {}
  for i = 1, n do
    -- include a few chars that sanitizer replaces
    local s = string.format("Line %d - with Unicode hyphen - and nbsp space.", i)
    table.insert(lines, s)
  end
  return lines
end

-- helper: generate text with lots of unusual unicode
local function generate_unicode_text(n)
  local lines = {}
  for i = 1, n do
    -- throw in zero-widths, bullets, arrows
    local s =
      string.format("☃️ -> Line %d with ZWSP and ellipsis... and arrows <-> ->.", i)
    table.insert(lines, s)
  end
  return lines
end

local function benchmark_sanitization()
  local test_cases = {
    small = generate_test_text(100), -- 100 lines
    medium = generate_test_text(1000), -- 1K lines
    large = generate_test_text(10000), -- 10K lines
    unicode_heavy = generate_unicode_text(1000), -- High Unicode density
  }

  for name, text in pairs(test_cases) do
    -- create scratch buffer
    local bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, text)

    local start_time = loop.hrtime()

    -- process whole buffer
    sanitizer.process_range(bufnr, 1, #text, true)

    local end_time = loop.hrtime()
    local duration_ms = (end_time - start_time) / 1e6

    print(string.format("%s: %.2fms", name, duration_ms))
  end
end

benchmark_sanitization()
