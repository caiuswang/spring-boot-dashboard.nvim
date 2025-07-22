local M = {
  inited = false
}
require("spring_boot.highlight").setup()
local highlight = require("spring_boot.highlight")

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

M.boot_app_modules = {}
--- @param location string
--- @param name string
--- @param isDeleted boolean
--- @param cp ClassPathData
function M.start_app_list_sync(location, name, isDeleted, cp)
  if cp and M.is_boot_app_class_path(cp) then
    table.insert(M.boot_app_modules, { location = location, name = name, isDeleted = isDeleted, cp = cp })
    -- print("This is a Spring Boot application: " .. name)
  else
    -- print("This is not a Spring Boot application: " .. name)
  end
end

---@param tree NuiTree
function M.on_module_click(tree)
  local windwin = vim.api.nvim_get_current_win()
  local line_nr = vim.api.nvim_win_get_cursor(windwin)[1]
  print("select line_nr: " .. line_nr)
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
  else
    print("this is leaf node")
  end

end
function M.list_boot_modules()
  if #M.boot_app_modules == 0 then
    vim.notify("No Spring Boot modules found in the current workspace", vim.log.levels.INFO)
    return
  end
  local NuiTree = require("nui.tree")
  local NuiLine = require("nui.line")
  local NuiSplit = require("nui.split")
  local split = NuiSplit({
    enter = true,
    relative = "editor",
    position = "left",
    size = {
      width = "20%",
      height = "20%",
    },
  })
  split:mount()
  -- not show line number
  local bufnfr = split.bufnr
  local nui_nodes = {}
  vim.api.nvim_buf_set_name(bufnfr, "Spring Boot Modules")
  for i, module in ipairs(M.boot_app_modules) do
    local node = NuiTree.Node({
      text = module.name,
      line = NuiLine({
        text = string.format("%s (%s)", module.name, module.location),
        hl_group = "NuiTreeNode",
        highlight = function (param)
          print("highlight" .. vim.inspect(param))
        end
      }),
      id = tostring(i),
      module = module,
    },
    {
      NuiTree.Node({
        text = module.location,
        hl_group = "SpringModule"
      })
    }
  )
  node:get_parent_id()
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
      line:append("", "SpringModuleIcon")
      line:append(node:is_expanded() and " " or " ", "SpecialChar")
    else
    end

    line:append(node.text, 'SpringModule')

    return line
  end,
})
split:map("n", "<CR>", function() M.on_module_click(tree) end, { noremap = true, silent = true })
tree:render()
end
function M.register_user_cmd()
  vim.api.nvim_create_user_command("SpringBootListModules", function()
    if not M.inited then
      vim.notify("Spring Boot classpath service not initialized", vim.log.levels.ERROR)
      return
    end
    M.list_boot_modules()
  end, {
  desc = "List all Spring Boot modules in the current workspace",
})
end



M.register_classpath_service = function(client)
  client.handlers["sts/addClasspathListener"] = function(_, result)
    local callbackCommandId = result.callbackCommandId
    vim.lsp.commands[callbackCommandId] = function(param, _)
      if type(param) ~= "table" or #param < 4 then
        print("Invalid parameters for sts/addClasspathListener")
        return
      end
      local location, name, isDeleted, classPathData = param[1], param[2], param[3], param[4]
      M.start_app_list_sync(location, name, isDeleted, classPathData)
      M.register_user_cmd()
      M.inited = true
      return require("spring_boot.util").boot_execute_command(callbackCommandId, param)
    end
    return require("spring_boot.jdtls").execute_command("sts.java.addClasspathListener", { callbackCommandId })
  end
  client.handlers["sts/removeClasspathListener"] = function(_, result)
    local callbackCommandId = result.callbackCommandId
    vim.lsp.commands[callbackCommandId] = nil
    return require("spring_boot.jdtls").execute_command("sts.java.removeClasspathListener", { callbackCommandId })
  end
end
return M
