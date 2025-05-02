-- llm/loaders/fragments_loader.lua - Fragment loading functionality for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Forward declarations
local utils = require('llm.utils')
local commands = require('llm.commands')
local plugins_manager = require('llm.managers.plugins_manager') -- Added

-- Check if llm-fragments-github plugin is installed and prompt to install if not
local function check_and_install_github_plugin(callback)
  if plugins_manager.is_plugin_installed("llm-fragments-github") then
    callback()
    return
  end

  vim.ui.select({
    "Yes", "No"
  }, {
    prompt = "llm-fragments-github plugin is required but not installed. Install it now?"
  }, function(install_choice)
    if install_choice == "Yes" then
      vim.notify("Installing llm-fragments-github plugin...", vim.log.levels.INFO)
      vim.schedule(function() -- Run install in background
        if plugins_manager.install_plugin("llm-fragments-github") then
          vim.notify("Installed llm-fragments-github plugin", vim.log.levels.INFO)
          callback() -- Continue after successful install
        else
          vim.notify("Failed to install llm-fragments-github plugin", vim.log.levels.ERROR)
          -- Do not call callback if install failed
        end
      end)
    else
      vim.notify("llm-fragments-github plugin is required to add GitHub repositories.", vim.log.levels.WARN)
      -- Do not call callback if user declines install
    end
  end)
end


-- Get all fragments from llm CLI (including those without aliases)
function M.get_all_fragments()
  local result = utils.safe_shell_command("llm fragments", "Failed to get fragments")
  if not result then
    return {}
  end
  
  local fragments = {}
  local current_fragment = nil

  for line in result:gmatch("[^\r\n]+") do
    if line:match("^%s*-%s+hash:%s+") then
      -- Start of a new fragment
      if current_fragment then
        table.insert(fragments, current_fragment)
      end

      local hash = line:match("hash:%s+([0-9a-f]+)")
      current_fragment = {
        hash = hash,
        aliases = {},
        source = "",
        content = "",
        datetime = "",
        in_aliases_section = false
      }
    elseif current_fragment and line:match("^%s+aliases:") then
      -- Just store that we're in the aliases section
      -- The actual aliases will be on the next lines with "  - alias_name" format
      current_fragment.in_aliases_section = true
    elseif current_fragment and current_fragment.in_aliases_section and line:match("^%s+-%s+") then
      -- This is an alias line in the format "  - alias_name"
      local alias = line:match("^%s+-%s+(.+)")
      if alias and #alias > 0 then
        table.insert(current_fragment.aliases, alias)
      end
    elseif current_fragment and current_fragment.in_aliases_section and not line:match("^%s+-%s+") then
      -- We've exited the aliases section
      current_fragment.in_aliases_section = nil
    elseif current_fragment and line:match("^%s+datetime_utc:") then
      current_fragment.datetime = line:match("datetime_utc:%s+'([^']+)'")
    elseif current_fragment and line:match("^%s+source:") then
      current_fragment.source = line:match("source:%s+(.+)")
    elseif current_fragment and line:match("^%s+content:") then
      -- Start of content
      current_fragment.content = line:match("content:%s+(.+)")
      if current_fragment.content:match("^%|-$") then
        current_fragment.content = ""
      end
    elseif current_fragment and current_fragment.content ~= "" then
      -- Continuation of content
      current_fragment.content = current_fragment.content .. "\n" .. line:gsub("^%s+", "")
    end
  end

  -- Add the last fragment
  if current_fragment then
    table.insert(fragments, current_fragment)
  end

  return fragments
end

-- Get fragments from llm CLI (only those with aliases)
function M.get_fragments()
  local result = utils.safe_shell_command("llm fragments", "Failed to get fragments")
  if not result then
    return {}
  end
  
  -- Debug the raw output from llm fragments (only in debug mode)
  local config = require('llm.config')
  if config.get('debug') then
    vim.notify("Raw fragments output:\n" .. result:sub(1, 500) .. (result:len() > 500 and "..." or ""), vim.log.levels.DEBUG)
  end

  local fragments = {}
  local current_fragment = nil
  local has_aliases = false

  for line in result:gmatch("[^\r\n]+") do
    if line:match("^%s*-%s+hash:%s+") then
      -- Start of a new fragment
      if current_fragment then
        -- Only add the fragment if it has at least one alias
        if #current_fragment.aliases > 0 then
          table.insert(fragments, current_fragment)
        end
      end

      local hash = line:match("hash:%s+([0-9a-f]+)")
      current_fragment = {
        hash = hash,
        aliases = {},
        source = "",
        content = "",
        datetime = "",
        in_aliases_section = false
      }
    elseif current_fragment and line:match("^%s+aliases:") then
      -- Just store that we're in the aliases section
      -- The actual aliases will be on the next lines with "  - alias_name" format
      current_fragment.in_aliases_section = true
    elseif current_fragment and current_fragment.in_aliases_section and line:match("^%s+-%s+") then
      -- This is an alias line in the format "  - alias_name"
      local alias = line:match("^%s+-%s+(.+)")
      if alias and #alias > 0 then
        table.insert(current_fragment.aliases, alias)
        local config = require('llm.config')
        if config.get('debug') then
          vim.notify("Added alias: " .. alias, vim.log.levels.DEBUG)
        end
      end
    elseif current_fragment and current_fragment.in_aliases_section and not line:match("^%s+-%s+") then
      -- We've exited the aliases section
      current_fragment.in_aliases_section = nil
    elseif current_fragment and line:match("^%s+datetime_utc:") then
      current_fragment.datetime = line:match("datetime_utc:%s+'([^']+)'")
    elseif current_fragment and line:match("^%s+source:") then
      current_fragment.source = line:match("source:%s+(.+)")
    elseif current_fragment and line:match("^%s+content:") then
      -- Start of content
      current_fragment.content = line:match("content:%s+(.+)")
      if current_fragment.content:match("^%|-$") then
        current_fragment.content = ""
      end
    elseif current_fragment and current_fragment.content ~= "" then
      -- Continuation of content
      current_fragment.content = current_fragment.content .. "\n" .. line:gsub("^%s+", "")
    end
  end

  -- Add the last fragment if it has aliases
  if current_fragment and #current_fragment.aliases > 0 then
    table.insert(fragments, current_fragment)
  end

  return fragments
end

-- Set an alias for a fragment
function M.set_fragment_alias(path, alias)
  local config = require('llm.config')
  local debug_mode = config.get('debug')
  
  -- Debug the command being executed
  local cmd = string.format('llm fragments set "%s" "%s"', alias, path)
  if debug_mode then
    vim.notify("Executing command: " .. cmd, vim.log.levels.INFO)
  end
  
  local result = utils.safe_shell_command(
    cmd,
    "Failed to set fragment alias"
  )
  
  -- Debug the result
  if debug_mode then
    if result then
      vim.notify("Command result: " .. result, vim.log.levels.INFO)
    else
      vim.notify("Command failed with nil result", vim.log.levels.ERROR)
    end
    
    -- Verify the alias was set by checking fragments
    vim.defer_fn(function()
      local verify_cmd = "llm fragments --aliases"
      local verify_result = utils.safe_shell_command(verify_cmd, "Failed to verify alias")
      if verify_result then
        vim.notify("Verification result:\n" .. verify_result, vim.log.levels.INFO)
      end
    end, 500)  -- Check after a short delay
  end

  return result ~= nil
end

-- Remove a fragment alias
function M.remove_fragment_alias(alias)
  local result = utils.safe_shell_command(
    string.format('llm fragments remove %s', alias),
    "Failed to remove fragment alias"
  )

  return result ~= nil
end


-- Show a specific fragment
function M.show_fragment(hash_or_alias)
  local result = utils.safe_shell_command(
    string.format('llm fragments show %s', hash_or_alias),
    "Failed to show fragment"
  )

  return result or ""
end

-- Get a list of files from NvimTree if available
function M.get_files_from_nvimtree()
  -- Check if NvimTree is available
  local has_nvimtree = pcall(require, "nvim-tree.api")
  if not has_nvimtree then
    return {}
  end

  local nvimtree_api = require("nvim-tree.api")
  local nodes = nvimtree_api.tree.get_nodes()

  if not nodes then
    return {}
  end

  local files = {}

  -- Helper function to recursively collect files
  local function collect_files(node, path_prefix)
    if not node then return end

    local path = path_prefix and (path_prefix .. "/" .. node.name) or node.name

    if node.type == "file" then
      table.insert(files, {
        name = node.name,
        path = path,
        absolute_path = fn.fnamemodify(path, ":p")
      })
    elseif node.type == "directory" and node.nodes then
      for _, child in ipairs(node.nodes) do
        collect_files(child, path)
      end
    end
  end

  -- Start collecting from root nodes
  if nodes.nodes then
    for _, node in ipairs(nodes.nodes) do
      collect_files(node, "")
    end
  end

  return files
end

-- Select a file to use as a fragment, calling a callback with the identifier on success
-- on_success_callback: function(identifier) - receives path or alias
-- force_manual_input: boolean, if true, bypasses NvimTree check
function M.select_file_as_fragment(on_success_callback, force_manual_input)
  local files = {}
  if not force_manual_input then
    files = M.get_files_from_nvimtree()
  end

  if #files == 0 then -- Always true if force_manual_input is true
    -- If NvimTree is not available or has no files, use vim.ui.input
    utils.floating_input({
      prompt = "Enter file path to use as fragment: "
    }, function(input)
      if not input or input == "" then return end
      
      -- Expand the input path (handles ~ and environment variables)
      local expanded_path = fn.expand(input)

      -- Check if file exists using the expanded path
      if fn.filereadable(expanded_path) == 0 then
        vim.notify("File not found: " .. expanded_path, vim.log.levels.ERROR)
        return
      end

      -- Ask for an optional alias
      utils.floating_input({
        prompt = "Set an alias for this fragment (optional): "
      }, function(alias)
        -- Use the expanded path when setting the alias
        if alias and alias ~= "" then
          if M.set_fragment_alias(expanded_path, alias) then
            vim.notify("Fragment alias set: " .. alias .. " -> " .. expanded_path, vim.log.levels.INFO)
            if on_success_callback then on_success_callback(alias) end -- Pass alias
          else
            vim.notify("Failed to set fragment alias for " .. expanded_path, vim.log.levels.ERROR)
          end
        else
          -- No alias provided, just register the fragment path
          -- The 'llm fragments set' command handles registration even without an alias.
          -- We use a placeholder alias that llm ignores but still registers the path.
          -- Note: llm >= 0.14 might not need this workaround. Check llm docs.
          if M.set_fragment_alias(expanded_path, "_") then
             vim.notify("File added as fragment (no alias): " .. expanded_path, vim.log.levels.INFO)
             if on_success_callback then on_success_callback(expanded_path) end -- Pass path
          else
             vim.notify("Failed to register fragment file: " .. expanded_path, vim.log.levels.ERROR)
          end
        end
      end)
    end)
    return
  end

  -- Format files for selection
  local items = {}
  for _, file in ipairs(files) do
    table.insert(items, file.path)
  end

  -- Use vim.ui.select to choose a file
  vim.ui.select(items, {
    prompt = "Select a file to use as fragment:",
    format_item = function(item)
      return item
    end
  }, function(choice, idx)
    if not choice then return end

    local selected_file = files[idx]
    if not selected_file then return end

    -- Ask for an optional alias
    utils.floating_input({
      prompt = "Set an alias for this fragment (optional): "
    }, function(alias)
      if alias and alias ~= "" then
        if M.set_fragment_alias(selected_file.absolute_path, alias) then
          vim.notify("Fragment alias set: " .. alias .. " -> " .. selected_file.path, vim.log.levels.INFO)
          if on_success_callback then on_success_callback(alias) end -- Pass alias
        else
          vim.notify("Failed to set fragment alias for " .. selected_file.path, vim.log.levels.ERROR)
        end
      else
        -- No alias provided, just register the fragment path
        -- Note: llm >= 0.14 might not need this workaround. Check llm docs.
        if M.set_fragment_alias(selected_file.absolute_path, "_") then
           vim.notify("File added as fragment (no alias): " .. selected_file.path, vim.log.levels.INFO)
           if on_success_callback then on_success_callback(selected_file.absolute_path) end -- Pass path
        else
           vim.notify("Failed to register fragment file: " .. selected_file.path, vim.log.levels.ERROR)
        end
      end
    end)
  end)
end

-- Add a GitHub repository as a fragment, calling callback with identifier on success
-- on_success_callback: function(identifier) - receives alias or path
function M.add_github_fragment(on_success_callback)
  check_and_install_github_plugin(function()
    -- Prompt for GitHub repository
    utils.floating_input({
      prompt = "Enter GitHub repository (owner/repo): "
    }, function(repo_input)
      if not repo_input or repo_input == "" then return end

      local fragment_path = "github:" .. repo_input

      -- Ask for an optional alias
      vim.ui.input({
        prompt = "Set an alias for this GitHub fragment (optional): "
      }, function(alias)
        if alias and alias ~= "" then
          if M.set_fragment_alias(fragment_path, alias) then
            vim.notify("GitHub fragment alias set: " .. alias .. " -> " .. fragment_path, vim.log.levels.INFO)
            if on_success_callback then on_success_callback(alias) end -- Pass alias
          else
            vim.notify("Failed to set GitHub fragment alias for " .. fragment_path, vim.log.levels.ERROR)
          end
        else
          -- No alias provided, just register the fragment path
          -- Note: llm >= 0.14 might not need this workaround. Check llm docs.
          if M.set_fragment_alias(fragment_path, "_") then
             vim.notify("GitHub repository added as fragment (no alias): " .. fragment_path, vim.log.levels.INFO)
             if on_success_callback then on_success_callback(fragment_path) end -- Pass path
          else
             vim.notify("Failed to register GitHub fragment: " .. fragment_path, vim.log.levels.ERROR)
          end
        end
      end)
    end)
  end)
end


return M
