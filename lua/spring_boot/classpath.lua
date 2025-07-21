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
    table.insert(M.boot_app_modules, name)
    print("This is a Spring Boot application: " .. name)
  else
    print("This is not a Spring Boot application: " .. name)
  end
end
function M.list_boot_modules()
  -- use plenary to show boot_app_modules in a menu that could be selected
  if #M.boot_app_modules == 0 then
    vim.notify("No Spring Boot modules found in the current workspace", vim.log.levels.INFO)
    return
  end
  local plenary = require("plenary.popup")
  plenary.create(
    M.boot_app_modules,
    {
      title = "Spring Boot Modules",
      border = true,
      min_width = 50,
      min_height = 10,
      height = #M.boot_app_modules,
      line = math.floor(vim.o.lines / 2),
      col = math.floor(vim.o.columns / 2),
      width = 50,
    }
  )
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
