local H = {}
H.setup = function ()
  H.ns_id = vim.api.nvim_create_namespace("spirng_boot_dashboard.nvim")
  H.create_highlight_group("SpringModuleIcon",   { "NeoTreeDirectoryIcon"}, nil, "#73cef4")
  H.create_highlight_group("SpringModule",  {}, nil, nil, "bold")
  H.create_highlight_group("SpringModuleBean", {}, nil, "#00a0ff", nil)
  H.create_highlight_group("SpringModuleMappings", {}, nil, "#00ff00", nil)
  vim.fn.sign_define('SpringBeanSign', { text = '', texthl = 'SpringModuleBean', linehl = 'SpringModuleBean'})
  vim.fn.sign_define('SpringMappingSign', { text = '', texthl = 'SpringModuleMappings', linehl = 'SpringModuleMappings'})
  return H
end

local function dec_to_hex(n, chars)
  chars = chars or 6
  local hex = string.format("%0" .. chars .. "x", n)
  while #hex < chars do
    hex = "0" .. hex
  end
  return hex
end

H.get_ns_id = function ()
  return H.ns_id
end

---If the given highlight group is not defined, define it.
---@param hl_group_name string The name of the highlight group.
---@param link_to_if_exists table A list of highlight groups to link to, in
--order of priority. The first one that exists will be used.
---@param background string|nil The background color to use, in hex, if the highlight group
--is not defined and it is not linked to another group.
---@param foreground string|nil The foreground color to use, in hex, if the highlight group
--is not defined and it is not linked to another group.
---@gui string|nil The gui to use, if the highlight group is not defined and it is not linked
--to another group.
---@return table table The highlight group values.
H.create_highlight_group = function(hl_group_name, link_to_if_exists, background, foreground, gui)
  local success, hl_group = pcall(vim.api.nvim_get_hl, H.ns_id, hl_group_name, true)
  if not success or not hl_group.fg or not hl_group.bg then
    for _, link_to in ipairs(link_to_if_exists) do
      success, hl_group = pcall(vim.api.nvim_get_hl, H.ns_id, link_to, true)
      if success then
        local new_group_has_settings = background or foreground or gui
        local link_to_has_settings = hl_group.fg or hl_group.bg
        if link_to_has_settings or not new_group_has_settings then
          vim.cmd("highlight default link " .. hl_group_name .. " " .. link_to)
          return hl_group
        end
      end
    end

    if type(background) == "number" then
      background = dec_to_hex(background)
    end
    if type(foreground) == "number" then
      foreground = dec_to_hex(foreground)
    end

    local cmd = "highlight default " .. hl_group_name
    if background then
      cmd = cmd .. " guibg=" .. background
    end
    if foreground then
      cmd = cmd .. " guifg=" .. foreground
    else
      cmd = cmd .. " guifg=NONE"
    end
    if gui then
      cmd = cmd .. " gui=" .. gui
    end
    vim.cmd(cmd)

    return {
      background = background and tonumber(background, 16) or nil,
      foreground = foreground and tonumber(foreground, 16) or nil,
    }
  end
  return hl_group
end
return H

