local fmt = string.format
local a = require('packer.async')
local log = require('packer.log')
local display = require('packer.display')

local Plugin = require('packer.plugin').Plugin

local M = {}



local function format_keys(value)
   local mapping, mode
   if type(value) == "string" then
      mapping = value
      mode = ''
   else
      mapping = value[2]
      mode = value[1] ~= '' and 'mode: ' .. value[1] or ''
   end
   return fmt('"%s", %s', mapping, mode)
end

local function format_cmd(value)
   return fmt('"%s"', value)
end

local function unpack_config_value(value, formatter)
   if type(value) == "string" then
      return { value }
   elseif type(value) == "table" then
      local result = {}
      for _, k in ipairs(value) do
         local item = formatter and formatter(k) or k
         table.insert(result, fmt('  - %s', item))
      end
      return result
   end
   return ''
end


local function format_values(key, value)
   if key == 'url' then
      return fmt('"%s"', value)
   end

   if key == 'keys' then
      return unpack_config_value(value, format_keys)
   end

   if key == 'commands' then
      return unpack_config_value(value, format_cmd)
   end

   if type(value) == 'function' then
      local info = debug.getinfo(value, 'Sl')
      return fmt('<Lua: %s:%s>', info.short_src, info.linedefined)
   end

   return vim.inspect(value)
end

local plugin_keys_exclude = {
   full_name = true,
   name = true,
   simple = true,
}

local function add_profile_data(plugin)
   local total_time = plugin.config_time or 0

   local path_times = require('packer.loader').path_times
   for p, d in pairs(path_times) do
      if vim.startswith(p, plugin.install_path) then
         plugin.plugin_times = plugin.plugin_times or {}
         plugin.plugin_times[p] = d
         total_time = total_time + d[1] + d[2]
      end
   end

   plugin.plugin_time = total_time
   return total_time
end

local function get_plugin_status(plugin)
   local config_lines = {}
   for key, value in pairs(plugin) do
      if not plugin_keys_exclude[key] then
         local details = format_values(key, value)
         if type(details) == "string" then

            table.insert(config_lines, 1, fmt('%s: %s', key, details))
         else
            vim.list_extend(config_lines, { fmt('%s: ', key), unpack(details) })
         end
      end
   end

   return config_lines
end

local function load_state(plugin)
   if not plugin.loaded then
      if plugin.start then
         return ' (not installed)'
      end
      return ' (not loaded)'
   end

   if plugin.lazy then
      return ' (manually loaded)'
   end

   return ''
end

M.run = a.sync(function()
   local plugins = require('packer.plugin').plugins
   if plugins == nil then
      log.warn('packer_plugins table is nil! Cannot run packer.status()!')
      return
   end

   local disp = display.display.open()

   disp:update_headline_message(fmt('Total plugins: %d', vim.tbl_count(plugins)))

   local total_time = 0
   for plugin_name, plugin in pairs(plugins) do
      local item = disp.items[plugin_name]
      item.expanded = false
      total_time = total_time + add_profile_data(plugin)
      local state = load_state(plugin) .. string.format(' (%.2fms)', plugin.plugin_time)
      disp:task_done(plugin_name, state, get_plugin_status(plugin))
   end

   disp:update_headline_message(fmt('Total plugins: %d (%.2fms)', vim.tbl_count(plugins), total_time))
end)

return M
