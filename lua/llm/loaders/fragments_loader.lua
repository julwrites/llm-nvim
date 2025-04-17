-- llm/loaders/fragments_loader.lua - Fragment loading functionality for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local api = vim.api
local fn = vim.fn

-- Forward declarations
local utils = require('llm.utils')
local commands = require('llm.commands')

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
  if current_fragment then
    if #current_fragment.aliases > 0 then
      table.insert(fragments, current_fragment)
    end
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

-- Select a file to use as a fragment
function M.select_file_as_fragment()
  local files = M.get_files_from_nvimtree()

  if #files == 0 then
    -- If NvimTree is not available or has no files, use vim.ui.input
    vim.ui.input({
      prompt = "Enter file path to use as fragment: "
    }, function(input)
      if not input or input == "" then return end

      -- Check if file exists
      if fn.filereadable(input) == 0 then
        vim.notify("File not found: " .. input, vim.log.levels.ERROR)
        return
      end

      -- Ask for an optional alias
      vim.ui.input({
        prompt = "Set an alias for this fragment (optional): "
      }, function(alias)
        if alias and alias ~= "" then
          if M.set_fragment_alias(input, alias) then
            vim.notify("Fragment alias set: " .. alias .. " -> " .. input, vim.log.levels.INFO)
          else
            vim.notify("Failed to set fragment alias", vim.log.levels.ERROR)
          end
        end

        vim.notify("File added as fragment: " .. input, vim.log.levels.INFO)
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
    vim.ui.input({
      prompt = "Set an alias for this fragment (optional): "
    }, function(alias)
      if alias and alias ~= "" then
        if M.set_fragment_alias(selected_file.absolute_path, alias) then
          vim.notify("Fragment alias set: " .. alias .. " -> " .. selected_file.path, vim.log.levels.INFO)
        else
          vim.notify("Failed to set fragment alias", vim.log.levels.ERROR)
        end
      end

      vim.notify("File added as fragment: " .. selected_file.path, vim.log.levels.INFO)
    end)
  end)
end

-- Prompt with fragments
function M.prompt_with_fragments(prompt)
  -- First, let the user select fragments
  local fragments_list = {}

  local function add_more_fragments()
    vim.ui.select({
      "Select file as fragment",
      "Enter fragment path/URL/alias",
      "Use GitHub repository as fragments",
      "Done - continue with prompt"
    }, {
      prompt = "Add fragments to prompt:"
    }, function(choice)
      if not choice then return end

      if choice == "Select file as fragment" then
        -- Let the user select a file
        M.select_file_as_fragment()

        -- Ask for the file path
        vim.ui.input({
          prompt = "Enter file path to use as fragment: "
        }, function(input)
          if not input or input == "" then
            add_more_fragments()
            return
          end

          -- Check if file exists
          if fn.filereadable(input) == 0 then
            vim.notify("File not found: " .. input, vim.log.levels.ERROR)
            add_more_fragments()
            return
          end

          table.insert(fragments_list, input)
          vim.notify("Added fragment: " .. input, vim.log.levels.INFO)
          add_more_fragments()
        end)
      elseif choice == "Enter fragment path/URL/alias" then
        vim.ui.input({
          prompt = "Enter fragment path/URL/alias: "
        }, function(input)
          if not input or input == "" then
            add_more_fragments()
            return
          end

          table.insert(fragments_list, input)
          vim.notify("Added fragment: " .. input, vim.log.levels.INFO)
          add_more_fragments()
        end)
      elseif choice == "Use GitHub repository as fragments" then
        vim.ui.input({
          prompt = "Enter GitHub repository (owner/repo): "
        }, function(input)
          if not input or input == "" then
            add_more_fragments()
            return
          end

          -- Check if the llm-fragments-github plugin is installed
          local result = utils.safe_shell_command("llm plugins", "Failed to check installed plugins")
          if not result or not result:match("llm%-fragments%-github") then
            vim.ui.select({
              "Yes", "No"
            }, {
              prompt = "llm-fragments-github plugin is required but not installed. Install it now?"
            }, function(install_choice)
              if install_choice == "Yes" then
                local install_result = utils.safe_shell_command(
                  "llm install llm-fragments-github",
                  "Failed to install llm-fragments-github plugin"
                )

                if install_result then
                  vim.notify("Installed llm-fragments-github plugin", vim.log.levels.INFO)
                else
                  vim.notify("Failed to install llm-fragments-github plugin", vim.log.levels.ERROR)
                  add_more_fragments()
                  return
                end
              else
                add_more_fragments()
                return
              end
            end)
          end

          table.insert(fragments_list, "github:" .. input)
          vim.notify("Added GitHub repository as fragments: " .. input, vim.log.levels.INFO)
          add_more_fragments()
        end)
      elseif choice == "Done - continue with prompt" then
        -- Now ask for the prompt
        vim.ui.input({
          prompt = "Enter prompt: "
        }, function(input_prompt)
          if not input_prompt or input_prompt == "" then
            vim.notify("Prompt cannot be empty", vim.log.levels.ERROR)
            return
          end

          -- Send the prompt with fragments
          commands.prompt(input_prompt, fragments_list)
        end)
      end
    end)
  end

  add_more_fragments()
end

-- Prompt with selection and fragments
function M.prompt_with_selection_and_fragments(prompt)
  local selection = utils.get_visual_selection()
  if selection == "" then
    api.nvim_err_writeln("No text selected")
    return
  end

  -- First, let the user select fragments
  local fragments_list = {}

  local function add_more_fragments()
    vim.ui.select({
      "Select file as fragment",
      "Enter fragment path/URL/alias",
      "Use GitHub repository as fragments",
      "Done - continue with prompt"
    }, {
      prompt = "Add fragments to prompt:"
    }, function(choice)
      if not choice then return end

      if choice == "Select file as fragment" then
        -- Let the user select a file
        M.select_file_as_fragment()

        -- Ask for the file path
        vim.ui.input({
          prompt = "Enter file path to use as fragment: "
        }, function(input)
          if not input or input == "" then
            add_more_fragments()
            return
          end

          -- Check if file exists
          if fn.filereadable(input) == 0 then
            vim.notify("File not found: " .. input, vim.log.levels.ERROR)
            add_more_fragments()
            return
          end

          table.insert(fragments_list, input)
          vim.notify("Added fragment: " .. input, vim.log.levels.INFO)
          add_more_fragments()
        end)
      elseif choice == "Enter fragment path/URL/alias" then
        vim.ui.input({
          prompt = "Enter fragment path/URL/alias: "
        }, function(input)
          if not input or input == "" then
            add_more_fragments()
            return
          end

          table.insert(fragments_list, input)
          vim.notify("Added fragment: " .. input, vim.log.levels.INFO)
          add_more_fragments()
        end)
      elseif choice == "Use GitHub repository as fragments" then
        vim.ui.input({
          prompt = "Enter GitHub repository (owner/repo): "
        }, function(input)
          if not input or input == "" then
            add_more_fragments()
            return
          end

          -- Check if the llm-fragments-github plugin is installed
          local result = utils.safe_shell_command("llm plugins", "Failed to check installed plugins")
          if not result or not result:match("llm%-fragments%-github") then
            vim.ui.select({
              "Yes", "No"
            }, {
              prompt = "llm-fragments-github plugin is required but not installed. Install it now?"
            }, function(install_choice)
              if install_choice == "Yes" then
                local install_result = utils.safe_shell_command(
                  "llm install llm-fragments-github",
                  "Failed to install llm-fragments-github plugin"
                )

                if install_result then
                  vim.notify("Installed llm-fragments-github plugin", vim.log.levels.INFO)
                else
                  vim.notify("Failed to install llm-fragments-github plugin", vim.log.levels.ERROR)
                  add_more_fragments()
                  return
                end
              else
                add_more_fragments()
                return
              end
            end)
          end

          table.insert(fragments_list, "github:" .. input)
          vim.notify("Added GitHub repository as fragments: " .. input, vim.log.levels.INFO)
          add_more_fragments()
        end)
      elseif choice == "Done - continue with prompt" then
        -- Now ask for the prompt
        vim.ui.input({
          prompt = "Enter prompt (optional): "
        }, function(input_prompt)
          -- Send the selection with fragments and optional prompt
          commands.prompt_with_selection(input_prompt or "", fragments_list)
        end)
      end
    end)
  end

  add_more_fragments()
end

return M
