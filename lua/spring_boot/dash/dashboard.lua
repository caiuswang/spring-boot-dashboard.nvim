local NuiSplit = require("nui.split")
local NuiTree = require("nui.tree")
local NuiLine = require("nui.line")
local buliltin = require("telescope.builtin")
local highlight = require("spring_boot.dash.highlight")
local M = {
  inited = false,
  is_spring_module_opend = false,
  boot_app_modules = {},
  windw_id = nil,
  buf_id = nil,
}

--- @param param table
M.setup = function(param)
  if type(param) ~= "table" or #param < 4 then
    vim.notify_once("Invalid parameters for sts/addClasspathListener", vim.log.levels.ERROR)
    return
  end
  require("spring_boot.dash.highlight").setup()
  local location, name, isDeleted, classPathData = param[1], param[2], param[3], param[4]
  M.start_app_list_sync(location, name, isDeleted, classPathData)
  M.inited = true
  M.intercept_buffer_open()
  M.register_user_cmd()
end


--- @class ClassPathData
--- @field entries CPE[]

--- @class CPE
--- @field kind string
--- @field path string
--- @field outputFolder string
--- @field sourceContainerUrl string
--- @field javadocContainerUrl string
--- @field isSystem boolean

--- @param cp ClassPathData
function M.is_boot_app_class_path(cp)
  if cp.entries ~= nil then
    local entries = cp.entries
    -- get path base name
    for _, cpe in ipairs(entries) do
      local cleaned_path = cpe.path:gsub("^file:///", "")
      local base_name = vim.fn.fnamemodify(cleaned_path, ":t")
      local r = base_name.match(base_name, "spring%-boot.*%.jar")
      if r ~= nil then
        return true
      end
    end
  end
  return false
end

--- @param location string
--- @param name string
--- @param isDeleted boolean
--- @param cp ClassPathData
function M.start_app_list_sync(location, name, isDeleted, cp)
  if cp and M.is_boot_app_class_path(cp) then
    table.insert(M.boot_app_modules, { location = location, name = name, isDeleted = isDeleted, cp = cp })
  end
end

---@param tree NuiTree
---@param bufnr number
function M.on_module_click(tree, bufnr)
  local windwin = vim.api.nvim_get_current_win()
  local line_nr = vim.api.nvim_win_get_cursor(windwin)[1]
  local node = tree:get_node(line_nr)
  if node == nil then
    return
  end
  if node:has_children() then
    if node:is_expanded() then
      node:collapse()
    else
      node:expand()
    end
    tree:render()
    local spring_module_bufnr = M.buf_id
    if spring_module_bufnr ~= nil then
      local total_lines = vim.api.nvim_buf_line_count(spring_module_bufnr)
      for i = 1, total_lines do
        local current_line_node = tree:get_node(i)
        if current_line_node then
          if current_line_node.text == "beans" then
            vim.fn.sign_place(0, "", "SpringBeanSign", spring_module_bufnr, { lnum = i })
          elseif current_line_node.text == "mappings" then
            vim.fn.sign_place(0, "", "SpringMappingSign", spring_module_bufnr, { lnum = i })
          end
        end
      end
    end
  else
    -- change to the main buffer
    -- vim.api.nvim_set_current_buf(bufnr)
    local opts = {
      prompt_title = "Spring Boot Modules",
      query = node.query,
      bufnr = bufnr
    }
    buliltin.lsp_workspace_symbols(opts)
  end
end

function M.list_boot_modules()
  if M.buf_id ~= nil then
    if vim.api.nvim_buf_is_valid(M.buf_id) then
      -- if the buffer is already opened, just split it and set buf_id
      local split = NuiSplit({
        enter = true,
        buf_options = {
          filetype = "SpringBootModules",
          modifiable = false,
          readonly = true,
          swapfile = false,
        },
        relative = "editor",
        position = "left",
        size = {
          width = "20%",
          height = "20%",
        },
      })
      split:mount()
      vim.api.nvim_set_current_win(split.winid)
      vim.api.nvim_set_current_buf(M.buf_id)
      M.windw_id = split.winid
      return
    end
  end
  local current_bufnr = vim.api.nvim_get_current_buf()
  local split = NuiSplit({
    bufnr = current_bufnr,
    enter = true,
    buf_options = {
      filetype = "SpringBootModules",
      modifiable = false,
      readonly = true,
      swapfile = false,
    },
    relative = "editor",
    position = "left",
    size = {
      width = "20%",
      height = "20%",
    },
  })
  split:mount()
  M.windw_id = split.winid
  -- set windo no line numbers
  local bufnfr = split.bufnr
  M.buf_id = bufnfr
  local nui_nodes = {}
  vim.api.nvim_buf_set_name(bufnfr, "Spring Boot Modules")
  for i, module in ipairs(M.boot_app_modules) do
    local cleaned_path = module.location:gsub("^file:", "")
    local beanQuery = "locationPrefix:file://" .. cleaned_path .. "?@+"
    local mappingQuery = "locationPrefix:file://" .. cleaned_path .. "?@/"
    local node = NuiTree.Node({
      text = module.name,
      id = tostring(i),
      module = module,
    },
    {
      NuiTree.Node({
        text = "beans",
        query = beanQuery,
        hl_group = "SpringModuleBean",
      }),
      NuiTree.Node({
        text = "mappings",
        query = mappingQuery,
        hl_group = "SpringModuleMappings"
      }),
    })
    table.insert(nui_nodes, node)
  end

  local tree = NuiTree({
    bufnr = bufnfr,
    ns_id = highlight.get_ns_id(),
    nodes = nui_nodes,
    prepare_node = function(node)
      local line = NuiLine()

      line:append(string.rep("  ", node:get_depth() - 1))

      if node:has_children() then
        if node:is_expanded() then
          line:append("󰉖", "SpringModuleIcon")
        else
          line:append("", "SpringModuleIcon")
        end

        line:append(node:is_expanded() and " " or " ", "SpecialChar")
      else
      end

      line:append(node.text, 'SpringModule')

      return line
    end,
  })
  split:map("n", "<CR>", function() M.on_module_click(tree, current_bufnr) end, { noremap = true, silent = true })
  tree:render()
  M.is_spring_module_opend = true
end

function M.register_user_cmd()
  -- add filetype option
  vim.cmd([[augroup SpringBootDashboard]])
  vim.cmd([[autocmd!]])
  vim.cmd([[autocmd FileType SpringBootModules setlocal nonumber]])
  vim.api.nvim_create_user_command("SpringBootListModules", function()
    if not M.inited then
      vim.notify("Spring Boot classpath service not initialized", vim.log.levels.ERROR)
      return
    end
    if M.windw_id ~= nil then
      if vim.api.nvim_win_is_valid(M.windw_id) then
        local buf = vim.api.nvim_win_get_buf(M.windw_id)
        if vim.api.nvim_get_option_value("filetype", {buf = buf}) == "SpringBootModules" then
          return
        else
          vim.api.nvim_set_current_win(M.windw_id)
          vim.api.nvim_set_current_buf(M.buf_id)
          return
        end
      else
        M.list_boot_modules()
      end
    else
      M.list_boot_modules()
    end
  end, {
  desc = "List all Spring Boot modules in the current workspace",
})
end

function M.intercept_buffer_open()

  vim.api.nvim_create_autocmd("BufWinEnter", {
    callback = function(p)
      local namespace_id = highlight.get_ns_id()
      vim.api.nvim_buf_set_extmark(p.buf, namespace_id, 0, 0, {
        virt_text = {{"⚡", "ErrorMsg"}},
        virt_text_pos = "overlay", -- or "eol", "overlay"
      })
      local current_wind = vim.api.nvim_get_current_win()
      local current_cursor = vim.api.nvim_win_get_cursor(current_wind)
      -- set ext_mark
      if M.windw_id and current_wind == M.windw_id then
        -- if the current window is the SpringModule window, recover the buffer
        vim.api.nvim_win_set_buf(M.windw_id, M.buf_id)
        local all_wins = vim.api.nvim_list_wins()
        for _, win in ipairs(all_wins) do
          if win ~= M.windw_id then
            vim.api.nvim_set_current_win(win)
            vim.api.nvim_win_set_buf(win, p.buf)
            -- set the cursor
            vim.api.nvim_win_set_cursor(win, current_cursor)
            return
          end
        end
        return
      end
    end,
  })
end

return M
