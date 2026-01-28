require "nvchad.mappings"

local map = vim.keymap.set

-- keybinding Rules
-- Avoiding conflicts with ghostty/tmux
-- Remain mostly consistent with zed

-- Keep NvChad defaults
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- File operations
map("n", "<C-o>", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map("n", "<C-S-o>", "<cmd>Telescope oldfiles<cr>", { desc = "Find recent files" })
map("n", "<C-s>", "<cmd>w<cr>", { desc = "Save file" })
map("i", "<C-s>", "<ESC><cmd>w<cr>a", { desc = "Save file in insert mode" })
map("v", "<C-s>", "<ESC><cmd>w<cr>", { desc = "Save file in visual mode" })

-- File explorer (Zed's ctrl+n for left dock)
map("n", "<C-n>", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file explorer" })

-- Navigation
map("n", "<C-b>", "<cmd>lua vim.lsp.buf.definition()<cr>", { desc = "Go to definition" })
map("n", "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", { desc = "Go to definition (alt)" })
map("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<cr>", { desc = "Go to declaration" })

-- Search operations
map("n", "<C-f>", "/", { desc = "Search in buffer" })
map("n", "<C-S-f>", "<cmd>Telescope live_grep<cr>", { desc = "Search in project" })

-- Editing operations
map("n", "<C-a>", "ggVG", { desc = "Select all" })
map("v", "<C-a>", "<ESC>ggVG", { desc = "Select all" })

-- Note: Ctrl+c/v handled by terminal, using defaults in nvim
-- For internal vim copy/paste, use visual mode + y/p
map("n", "<C-z>", "u", { desc = "Undo" })
map("n", "<C-S-z>", "<C-r>", { desc = "Redo" })

-- Comments (using nvim-comment or similar plugin)
map("n", "<C-/>", "gcc", { desc = "Toggle comment", remap = true })
map("v", "<C-/>", "gc", { desc = "Toggle comment", remap = true })

-- Indentation (avoiding Ctrl+] conflict with tmux)
map("v", "<Tab>", ">gv", { desc = "Indent" })
map("v", "<S-Tab>", "<gv", { desc = "Outdent" })
map("n", ">>", ">>", { desc = "Indent line" })
map("n", "<<", "<<", { desc = "Outdent line" })

-- Terminal mode escaping (since ctrl+` conflicts might occur)
map("t", "<ESC><ESC>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("t", "jk", "<C-\\><C-n>", { desc = "Exit terminal mode (jk)" })

-- Quick buffer switching (alternative to tmux tab switching inside vim)
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Close window" })
map("n", "<leader>w", "<cmd>bd<cr>", { desc = "Close buffer" })
map("n", "<leader>W", "<cmd>bd!<cr>", { desc = "Force close buffer" })
map("n", "<leader>1", "<cmd>BufferLineGoToBuffer 1<cr>", { desc = "Go to buffer 1" })
map("n", "<leader>2", "<cmd>BufferLineGoToBuffer 2<cr>", { desc = "Go to buffer 2" })
map("n", "<leader>3", "<cmd>BufferLineGoToBuffer 3<cr>", { desc = "Go to buffer 3" })
map("n", "<leader>4", "<cmd>BufferLineGoToBuffer 4<cr>", { desc = "Go to buffer 4" })
map("n", "<leader>5", "<cmd>BufferLineGoToBuffer 5<cr>", { desc = "Go to buffer 5" })
map("n", "<leader>6", "<cmd>BufferLineGoToBuffer 6<cr>", { desc = "Go to buffer 6" })
map("n", "<leader>7", "<cmd>BufferLineGoToBuffer 7<cr>", { desc = "Go to buffer 7" })
map("n", "<leader>8", "<cmd>BufferLineGoToBuffer 8<cr>", { desc = "Go to buffer 8" })
map("n", "<leader>9", "<cmd>BufferLineGoToBuffer 9<cr>", { desc = "Go to buffer 9" })

-- Quick save like
map("n", "<leader>s", "<cmd>w<cr>", { desc = "Quick save" })

-- LSP operations
map("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<cr>", { desc = "Code actions" })
map("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<cr>", { desc = "Rename symbol" })
map("n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>", { desc = "Hover documentation" })
map("n", "<leader>D", "<cmd>lua vim.lsp.buf.type_definition()<cr>", { desc = "Type definition" })

-- Diagnostics
map("n", "<leader>e", "<cmd>lua vim.diagnostic.open_float()<cr>", { desc = "Show diagnostic" })
map("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<cr>", { desc = "Previous diagnostic" })
map("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<cr>", { desc = "Next diagnostic" })
