local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local utils = require("utils")
local g = vim.g

local function fzf_key(lhs, fn, desc)
  return {
    lhs,
    function()
      require("fzf-lua")[fn]()
    end,
    desc = desc,
  }
end

local prettier_markers = {
  ".prettierrc",
  ".prettierrc.json",
  ".prettierrc.json5",
  ".prettierrc.yml",
  ".prettierrc.yaml",
  ".prettierrc.js",
  ".prettierrc.cjs",
  ".prettierrc.mjs",
  "prettier.config.js",
  "prettier.config.cjs",
  "prettier.config.mjs",
}

local function repo_formatter(bufnr)
  if vim.fs.root(bufnr, { "biome.json", "biome.jsonc" }) then
    return { "biome" }
  end
  if vim.fs.root(bufnr, prettier_markers) then
    return { "prettier" }
  end
  return {}
end

local formatters_by_ft = {
  lua = { "stylua" },
  go = { "goimports", "gofmt", stop_after_first = true },
  python = { "ruff_format" },
  rust = { "rustfmt" },
}

for _, filetype in ipairs({
  "css",
  "html",
  "javascript",
  "javascriptreact",
  "json",
  "jsonc",
  "markdown",
  "scss",
  "svelte",
  "typescript",
  "typescriptreact",
  "vue",
  "yaml",
}) do
  formatters_by_ft[filetype] = repo_formatter
end

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    lazyrepo,
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

local function sanitizer_action(action)
  return function(...)
    local sanitizer = require("plugins.llm_sanitizer")
    sanitizer.setup({})
    return sanitizer[action](...)
  end
end

vim.api.nvim_create_user_command("FormatLLMOutput", sanitizer_action("format"), { range = true })
vim.api.nvim_create_user_command(
  "LLMSanitizerHighlightShow",
  sanitizer_action("highlight_show"),
  {}
)
vim.api.nvim_create_user_command(
  "LLMSanitizerHighlightClear",
  sanitizer_action("highlight_clear"),
  {}
)
vim.api.nvim_create_user_command(
  "LLMSanitizerHighlightToggle",
  sanitizer_action("highlight_toggle"),
  {}
)

vim.keymap.set("n", "<leader>lf", sanitizer_action("format"), { desc = "Format LLM output" })
vim.keymap.set(
  "n",
  "<leader>ls",
  sanitizer_action("highlight_toggle"),
  { desc = "Toggle LLM Sanitizer highlights" }
)

require("lazy").setup({
  defaults = { lazy = true },
  ui = { border = "rounded" },
  performance = {
    rtp = {
      disabled_plugins = {
        "netrwPlugin",
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  spec = {
    { "tpope/vim-surround", event = "VeryLazy" },
    {
      "junegunn/vim-easy-align",
      keys = {
        { "ga", "<Plug>(EasyAlign)", desc = "Easy Align initiation" },
      },
    },
    {
      url = "https://codeberg.org/andyg/leap.nvim",
      keys = {
        { "s", "<Plug>(leap)", mode = "n" },
        { "S", "<Plug>(leap-backward)", mode = "n" },
      },
    },
    {
      "sainnhe/sonokai",
      lazy = false,
      priority = 1000,
      config = function()
        -- Optionally configure and load the colorscheme
        g.sonokai_enable_italic = true
        g.sonokai_style = "andromeda"
        g.sonokai_better_performance = 1
        g.sonokai_float_style = "blend"
        g.sonokai_show_eob = 0
        g.sonokai_transparent_background = 2
        vim.cmd.colorscheme("sonokai")

        local palette = vim.fn["sonokai#get_palette"](g.sonokai_style, vim.empty_dict())
        local statusline = { fg = palette.fg[1], bg = palette.bg3[1] }
        local statusline_nc = { fg = palette.grey[1], bg = palette.bg1[1] }
        vim.api.nvim_set_hl(0, "StatusLine", statusline)
        vim.api.nvim_set_hl(0, "StatusLineTerm", statusline)
        vim.api.nvim_set_hl(0, "StatusLineNC", statusline_nc)
        vim.api.nvim_set_hl(0, "StatusLineTermNC", statusline_nc)
      end,
    },
    {
      "ibhagwan/fzf-lua",
      cmd = "FzfLua",
      keys = {
        fzf_key("<leader>t", "global", "Go anywhere"),
        fzf_key("<leader>rg", "live_grep", "Ripgrep"),
        fzf_key("<leader>b", "buffers", "Buffers"),
        fzf_key("<leader>rr", "resume", "Resume last picker"),

        fzf_key("<leader>ld", "lsp_definitions", "LSP definitions"),
        fzf_key("<leader>lr", "lsp_references", "LSP references"),
        fzf_key("<leader>li", "lsp_implementations", "LSP implementations"),
        fzf_key("<leader>lx", "diagnostics_workspace", "Workspace diagnostics"),

        fzf_key("<leader>gs", "git_status", "Git status"),
        fzf_key("<leader>gh", "git_hunks", "Git hunks"),
        fzf_key("<leader>gb", "git_bcommits", "Buffer commits"),
        {
          "<leader>ms",
          function()
            if vim.bo.filetype ~= "markdown" then
              vim.notify("Current buffer is not Markdown", vim.log.levels.INFO)
              return
            end

            require("fzf-lua").grep_curbuf({
              search = [[^#{1,6}\s+]],
              no_esc = true,
            })
          end,
          desc = "Markdown headings",
        },
        {
          "<leader>st",
          ":lua require('fzf-lua').grep({search='TODO|HACK|PERF|NOTE|FIX', no_esc=true})<CR>",
          desc = "Search tags TODO|FIX...",
        },
      },
    },
    {
      "lewis6991/gitsigns.nvim",
      event = { "BufReadPre", "BufNewFile" },
      opts = {
        on_attach = function(bufnr)
          local gitsigns = require("gitsigns")

          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          map("n", "]h", function()
            if vim.wo.diff then
              vim.cmd.normal({ "]c", bang = true })
            else
              gitsigns.nav_hunk("next")
            end
          end, "Next hunk")
          map("n", "[h", function()
            if vim.wo.diff then
              vim.cmd.normal({ "[c", bang = true })
            else
              gitsigns.nav_hunk("prev")
            end
          end, "Previous hunk")

          map("n", "<leader>hp", gitsigns.preview_hunk, "Preview hunk")
          map("n", "<leader>hs", gitsigns.stage_hunk, "Stage hunk")
          map("n", "<leader>hr", gitsigns.reset_hunk, "Reset hunk")
          map("v", "<leader>hs", function()
            gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Stage hunk")
          map("v", "<leader>hr", function()
            gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Reset hunk")

          map("n", "<leader>hb", function()
            gitsigns.blame_line({ full = true })
          end, "Blame line")
          map("n", "<leader>hd", gitsigns.diffthis, "Diff against index")
          map("n", "<leader>hD", function()
            gitsigns.diffthis("~")
          end, "Diff against base")
        end,
      },
    },
    {
      "stevearc/conform.nvim",
      keys = {
        {
          "<leader>f",
          function()
            require("conform").format()
          end,
          mode = { "n", "v" },
          desc = "Format buffer",
        },
      },
      opts = {
        default_format_opts = {
          lsp_format = "fallback",
        },
        formatters_by_ft = formatters_by_ft,
      },
    },
    {
      "neovim/nvim-lspconfig",
      event = { "BufReadPost", "BufNewFile", "VeryLazy" },

      config = function()
        local function configure_server(name, config)
          vim.lsp.config(name, config or {})
        end

        local function enable_server(name, executable)
          if executable == nil or vim.fn.executable(executable) == 1 then
            vim.lsp.enable(name)
          end
        end

        vim.diagnostic.config({
          virtual_text = false,
          signs = {
            text = {
              [vim.diagnostic.severity.ERROR] = utils.icons.diagnostics.Error,
              [vim.diagnostic.severity.WARN] = utils.icons.diagnostics.Warn,
              [vim.diagnostic.severity.INFO] = utils.icons.diagnostics.Info,
              [vim.diagnostic.severity.HINT] = utils.icons.diagnostics.Hint,
            },
          },
          jump = {
            on_jump = function(diagnostic, bufnr)
              if not diagnostic then
                return
              end
              vim.diagnostic.open_float({
                bufnr = bufnr,
                pos = { diagnostic.lnum, diagnostic.col },
                focus = false,
              })
            end,
          },
        })

        local function complete_item_convert(item)
          local kind = vim.lsp.protocol.CompletionItemKind[item.kind]
          local icon = kind and utils.icons.lsp[kind]
          if not icon then
            return {}
          end
          return { kind = icon .. kind }
        end

        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(args)
            local bufnr = args.buf
            local bufopts = { noremap = true, silent = true, buffer = bufnr }

            vim.lsp.completion.enable(true, args.data.client_id, bufnr, {
              convert = complete_item_convert,
            })

            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
            vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
            vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, bufopts)

            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, bufopts)
          end,
        })

        configure_server("lua_ls", {
          settings = {
            Lua = {
              runtime = {
                version = "LuaJIT",
                path = vim.split(package.path, ";"),
              },
              diagnostics = {
                globals = { "vim" },
              },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
              },
              telemetry = { enable = false },
            },
          },
        })

        configure_server("ts_ls")
        configure_server("sourcekit")
        configure_server("vue_ls")
        configure_server("svelte")
        configure_server("gopls")
        configure_server("rust_analyzer", {
          settings = {
            ["rust-analyzer"] = {},
          },
        })

        configure_server("basedpyright", {
          cmd = { "basedpyright-langserver", "--stdio" },
          single_file_support = false,
          root_markers = {
            "pyrightconfig.json",
            "uv.lock",
            ".git",
          },
          before_init = function(_, config)
            local python = vim.fs.joinpath(config.root_dir, ".venv", "bin", "python")
            if vim.fn.executable(python) == 1 then
              config.settings = config.settings or {}
              config.settings.python = config.settings.python or {}
              config.settings.python.pythonPath = python
            end
          end,
          settings = {
            basedpyright = {
              disableOrganizeImports = true,
              analysis = {
                diagnosticMode = "openFilesOnly",
              },
            },
          },
        })

        configure_server("ruff", {
          cmd = { "ruff", "server" },
          root_markers = {
            "pyproject.toml",
            "ruff.toml",
            ".ruff.toml",
            ".git",
          },
          init_options = {
            settings = {
              organizeImports = true,
              fixAll = true,
              showSyntaxErrors = true,
            },
          },
        })

        enable_server("lua_ls", "lua-language-server")
        enable_server("ts_ls", "typescript-language-server")
        enable_server("svelte", "svelteserver")
        enable_server("rust_analyzer", "rust-analyzer")
        enable_server("sourcekit", "sourcekit-lsp")
        enable_server("vue_ls", "vue-language-server")
        enable_server("gopls", "gopls")
        enable_server("basedpyright", "basedpyright-langserver")
        enable_server("ruff", "ruff")
      end,
    },
    {
      "nvim-treesitter/nvim-treesitter",
      lazy = false,
      build = ":TSUpdate",
      config = function()
        local treesitter = require("nvim-treesitter")
        local parsers = {
          "bash",
          "css",
          "diff",
          "gitcommit",
          "gitignore",
          "go",
          "gomod",
          "gowork",
          "hcl",
          "html",
          "javascript",
          "json",
          "lua",
          "markdown",
          "markdown_inline",
          "python",
          "rust",
          "svelte",
          "swift",
          "terraform",
          "toml",
          "tsx",
          "typescript",
          "vim",
          "vue",
          "yaml",
        }

        treesitter.setup({})
        vim.treesitter.language.register("json", "jsonc")

        vim.api.nvim_create_user_command("TSInstallConfigured", function()
          local installed = {}
          for _, parser in ipairs(treesitter.get_installed()) do
            installed[parser] = true
          end

          local missing = vim.tbl_filter(function(parser)
            return not installed[parser]
          end, parsers)

          if #missing == 0 then
            vim.notify("All configured Treesitter parsers are already installed")
            return
          end

          treesitter.install(missing)
        end, { desc = "Install missing Treesitter parsers from this config" })

        local group = vim.api.nvim_create_augroup("TreesitterHighlighting", { clear = true })
        vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
          group = group,
          callback = function(args)
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(args.buf) then
                return
              end
              if vim.treesitter.highlighter.active[args.buf] then
                return
              end
              pcall(vim.treesitter.start, args.buf)
            end)
          end,
        })
      end,
    },
    {
      "nvim-treesitter/nvim-treesitter-textobjects",
      dependencies = { "nvim-treesitter/nvim-treesitter" },
      lazy = false,
      config = function()
        local select = require("nvim-treesitter-textobjects.select")
        local move = require("nvim-treesitter-textobjects.move")
        local swap = require("nvim-treesitter-textobjects.swap")

        require("nvim-treesitter-textobjects").setup({
          select = {
            lookahead = true,
          },
          move = {
            set_jumps = true,
          },
        })

        local function map_textobject(lhs, query_string, desc)
          vim.keymap.set({ "x", "o" }, lhs, function()
            select.select_textobject(query_string, "textobjects")
          end, { desc = desc })
        end

        local function map_move(lhs, move_fn, query_string, desc)
          vim.keymap.set({ "n", "x", "o" }, lhs, function()
            move_fn(query_string, "textobjects")
          end, { desc = desc })
        end

        map_textobject("aa", "@parameter.outer", "Select around parameter")
        map_textobject("ia", "@parameter.inner", "Select inside parameter")
        map_textobject("af", "@function.outer", "Select around function")
        map_textobject("if", "@function.inner", "Select inside function")
        map_textobject("ac", "@class.outer", "Select around class")
        map_textobject("ic", "@class.inner", "Select inside class")

        map_move("]m", move.goto_next_start, "@function.outer", "Next function")
        map_move("]M", move.goto_next_end, "@function.outer", "Next function end")
        map_move("[m", move.goto_previous_start, "@function.outer", "Previous function")
        map_move("[M", move.goto_previous_end, "@function.outer", "Previous function end")
        map_move("]C", move.goto_next_start, "@class.outer", "Next class")
        map_move("[C", move.goto_previous_start, "@class.outer", "Previous class")
        map_move("]a", move.goto_next_start, "@parameter.inner", "Next parameter")
        map_move("[a", move.goto_previous_start, "@parameter.inner", "Previous parameter")

        vim.keymap.set("n", "<leader>a", function()
          swap.swap_next("@parameter.inner", "textobjects")
        end, { desc = "Swap parameter with next" })
        vim.keymap.set("n", "<leader>A", function()
          swap.swap_previous("@parameter.inner", "textobjects")
        end, { desc = "Swap parameter with previous" })
      end,
    },
  },
})
