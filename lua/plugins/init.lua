local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local utils = require("utils")
local g = vim.g

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

require("plugins.llm_sanitizer").setup({})

require("lazy").setup({
  defaults = { lazy = true },
  ui = { border = "rounded" },
  performance = {
    cache = {
      enabled = true,
    },
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
    "numToStr/Comment.nvim",
    {
      "junegunn/vim-easy-align",
      keys = {
        { "ga", "<Plug>(EasyAlign)", desc = "Easy Align initiation" },
      },
    },
    {
      url = "https://codeberg.org/andyg/leap.nvim",
      lazy = false
    },
    {
      "L3MON4D3/LuaSnip",
      version = "v2.*",
      build = "make install_jsregexp",
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
        g.sonokai_transparent_background = 1
        vim.cmd.colorscheme("sonokai")
      end,
    },
    {
      "ibhagwan/fzf-lua",
      cmd = "FzfLua",
      keys = {
        { "<leader>t",  ":FzfLua files<cr>",     desc = "Find files" },
        { "<leader>rg", ":FzfLua live_grep<cr>", desc = "Ripgrep" },
        { "<leader>b",  ":FzfLua buffers<cr>",   desc = "Buffers" },
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
      "neovim/nvim-lspconfig",
      event = { "BufReadPost", "BufNewFile", "VeryLazy" },
      dependencies = {
        {
          "mason-org/mason.nvim",
          opts = {},
          build = ":MasonUpdate",
        },
        {
          "mason-org/mason-lspconfig.nvim",
          opts = function()
            return {
              automatic_enable = false,
            }
          end,
        },
        "hrsh7th/nvim-cmp",
        {
          "lewis6991/gitsigns.nvim",
          init = function()
            require("gitsigns").setup()
          end,
        },
        {
          "glepnir/lspsaga.nvim",
          opts = {
            code_action = {
              show_server_name = true,
              extend_gitsigns = false,
            },
            lightbulb = {
              enable = false,
            },
            diagnostic = {
              on_insert = false,
              on_insert_follow = false,
            },
            rename = {
              in_select = false,
            },
          },
        },
      },

      config = function()
        local capabilities = require("cmp_nvim_lsp").default_capabilities()
        local util = require("lspconfig.util")
        local function configure_server(name, config)
          vim.lsp.config(name, vim.tbl_deep_extend("force", {
            capabilities = capabilities,
          }, config or {}))
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
        })

        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(args)
            local bufnr = args.buf
            local bufopts = { noremap = true, silent = true, buffer = bufnr }

            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
            vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
            vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
            vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, bufopts)

            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
            vim.keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", bufopts)

            vim.keymap.set("n", "<leader>f", function()
              vim.lsp.buf.format({ async = false })
            end, bufopts)

            vim.keymap.set("n", "]c", "<cmd>Lspsaga diagnostic_jump_next<CR>", bufopts)
            vim.keymap.set("n", "[c", "<cmd>Lspsaga diagnostic_jump_prev<CR>", bufopts)
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
            local python = util.path.join(config.root_dir, ".venv", "bin", "python")
            if vim.fn.executable(python) == 1 then
              config.settings = config.settings or {}
              config.settings.python = config.settings.python or {}
              config.settings.python.pythonPath = python
            end
          end,
          settings = {
            basedpyright = {
              disableOrganizeImports = true,
            },
            python = {
              analysis = {
                diagnosticMode = "workspace",
                useLibraryCodeForTypes = true,
                autoSearchPaths = false,
                typeCheckingMode = "standard",
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
        enable_server("basedpyright", "basedpyright-langserver")
        enable_server("ruff", "ruff")
      end,
    },
    {
      "hrsh7th/nvim-cmp",
      event = "InsertEnter",
      dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-nvim-lua",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
      },
      opts = function()
        local cmp = require("cmp")
        return {
          enabled = function()
            local in_prompt = vim.bo.buftype == "prompt"
            if in_prompt then
              return false
            end
            local context = require("cmp.config.context")
            return not (
              context.in_treesitter_capture("comment") == true
              or context.in_syntax_group("Comment")
            )
          end,
          formatting = {
            format = function(_, item)
              item.kind = string.format("%s %s", utils.icons.lsp[item.kind], item.kind)
              return item
            end,
          },
          confirmation = {
            get_commit_characters = function()
              return {}
            end,
          },
          view = {
            entries = "custom",
          },
          completion = {
            completeopt = "menu,menuone,noinsert",
            keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],
            keyword_length = 1,
          },
          snippet = {
            expand = function(args)
              require("luasnip").lsp_expand(args.body)
            end,
          },
          mapping = {
            ["<C-n>"] = cmp.mapping.select_next_item({
              behavior = cmp.SelectBehavior.Insert,
            }),
            ["<C-p>"] = cmp.mapping.select_prev_item({
              behavior = cmp.SelectBehavior.Insert,
            }),
            ["<C-d>"] = cmp.mapping.scroll_docs(-4),
            ["<C-f>"] = cmp.mapping.scroll_docs(4),
            ["<C-e>"] = cmp.mapping.abort(),
            ["<C-y>"] = cmp.mapping(
              cmp.mapping.confirm({
                behavior = cmp.ConfirmBehavior.Insert,
                select = true,
              }),
              { "i", "c" }
            ),

            ["<c-space>"] = cmp.mapping({
              i = cmp.mapping.complete(),
              c = function(
                  _ --[[fallback]]
              )
                if cmp.visible() then
                  if not cmp.confirm({ select = true }) then
                    return
                  end
                else
                  cmp.complete()
                end
              end,
            }),
            ["<tab>"] = cmp.config.disable,
            ["<C-k>"] = cmp.mapping.complete({ reason = cmp.ContextReason.Auto }),
          },
          sources = cmp.config.sources({
            { name = "cody" },
            { name = "nvim_lsp", keyword_length = 2 },
            { name = "nvim_lua" },
            -- { name = "luasnip" },
            { name = "path" },
            { name = "buffer",   keyword_length = 2 },
          }),
          preselect = cmp.PreselectMode.None,
          sorting = {
            comparator = {
              cmp.config.compare.offset,
              cmp.config.compare.exact,
              cmp.config.compare.score,
              cmp.config.compare.recently_used,
              cmp.config.compare.kind,
            },
          },
        }
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
          "html",
          "javascript",
          "json",
          "lua",
          "markdown",
          "markdown_inline",
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

        require("nvim-treesitter-textobjects").setup({
          select = {
            lookahead = true,
          },
        })

        local function map_textobject(lhs, query_string, desc)
          vim.keymap.set({ "x", "o" }, lhs, function()
            select.select_textobject(query_string, "textobjects")
          end, { desc = desc })
        end

        map_textobject("aa", "@parameter.outer", "Select around parameter")
        map_textobject("ia", "@parameter.inner", "Select inside parameter")
        map_textobject("af", "@function.outer", "Select around function")
        map_textobject("if", "@function.inner", "Select inside function")
        map_textobject("ac", "@class.outer", "Select around class")
        map_textobject("ic", "@class.inner", "Select inside class")
      end,
    },
  },
  checker = { enabled = false },
})
