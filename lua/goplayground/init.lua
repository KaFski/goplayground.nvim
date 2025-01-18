local M = {}

local contents = require('goplayground.templates')

---@type Window
local window = {}

---@class Window: table
---@field bufnr number?
---@field window number?
---@field temp_file string?
---@field fd number?

local function execute(command)
	local lines = vim.api.nvim_buf_get_lines(window.bufnr, 0, -1, false)
	local content = table.concat(lines, "\n")

	vim.loop.fs_write(window.fd, content, 0, function(err)
		if err then
			print("Error writing to file", err)
			return
		end
	end)

	local cmd = string.format("go %s %s", command, window.temp_file)
	local output = vim.fn.system(cmd)

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(output, "\n"))
	vim.bo[bufnr].modifiable = false

	local new_window = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		row = vim.o.lines,
		col = vim.o.columns * 0.05,
		width = math.floor(vim.o.columns * 0.8),
		height = math.floor(vim.o.lines * 0.2),
		border = "single",
		style = "minimal",
	})

	vim.keymap.set('n', '<C-q>', function() M.close { bufnr = bufnr, window = new_window } end, { buffer = bufnr })
end

---@class Template: table
---@field content string
---@field extension string
---@field command string

---@param template Template
local function open_window(template)
	local temp_file = vim.fn.tempname() .. template.extension
	local file_descriptor
	vim.loop.fs_open(temp_file, "w", 438, function(err, fd)
		file_descriptor = fd
		if err then
			print("Error opening file", err)
			return
		end
	end)

	local bufnr = vim.api.nvim_create_buf(true, true)
	local new_window = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		row = vim.o.lines,
		col = vim.o.columns * 0.05,
		width = math.floor(vim.o.columns * 0.8),
		height = math.floor(vim.o.lines * 0.9),
		border = "single",
		style = "minimal",
	})

	vim.api.nvim_buf_set_name(bufnr, temp_file)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(template.content, "\n"))

	vim.bo[bufnr].filetype = "go"
	vim.bo[bufnr].tabstop = 4
	vim.wo[new_window].number = true
	vim.wo[new_window].relativenumber = true

	local client = vim.lsp.get_clients({
		name = "gopls"
	})[1]
	if client then
		vim.lsp.buf_attach_client(bufnr, client.id)
		print("gopld LSP client attached")
	end

	window = {
		bufnr = bufnr,
		window = new_window,
		temp_file = temp_file,
		fd = file_descriptor,
	}

	vim.keymap.set('n', '<C-q>', function() M.close(window) end, { buffer = bufnr })
	vim.keymap.set('n', '<C-x>', function() execute(template.command) end, { buffer = bufnr })
end


M.open_playground = function()
	open_window { content = contents.main, extension = ".go", command = "run" }
end

M.open_test = function()
	open_window { content = contents.test, extension = "_test.go", command = "test" }
end

---@param win Window
M.close = function(win)
	if vim.api.nvim_win_is_valid(win.window) then
		vim.api.nvim_win_close(win.window, true)
	end

	if vim.api.nvim_buf_is_valid(win.bufnr) then
		vim.api.nvim_buf_delete(win.bufnr, { force = true })
	end

	if vim.fn.filereadable(win.temp_file) then
		vim.fn.delete(win.temp_file)
	end
end

return M
