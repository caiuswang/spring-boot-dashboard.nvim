local M = {
  inited = false
}

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
-- Define the click handler
function M.on_module_click()
  local line = vim.fn.line(".")
  local module_name = M.boot_app_modules[line]
  print("Clicked module: " .. module_name) -- Replace with your desired action
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
      }),
      id = tostring(i),
      module = module,
    })
    node.on_click = function()
      M.on_module_click()
    end
    table.insert(nui_nodes, node)
  end

  local tree = NuiTree({
    bufnr = bufnfr,
    ns_id = vim.api.nvim_create_namespace("spring_boot_modules"),
    nodes = nui_nodes,
    prepare_node = function(node)
      local line = NuiLine()

      line:append(string.rep("  ", node:get_depth() - 1))

      if node:has_children() then
        line:append(node:is_expanded() and " " or " ", "SpecialChar")
      else
        line:append("  ")
      end

      line:append("🛞")
      line:append(node.text)

      return line
    end,
  })
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
