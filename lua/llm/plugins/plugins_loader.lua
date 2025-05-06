-- llm/loaders/plugins_loader.lua - Plugin data loader for llm-nvim
-- License: Apache 2.0

local M = {}

-- Forward declarations
local utils = require('llm.utils')
local cache_file = utils.get_config_path('plugins_cache.json')
local cache_expiry = 86400 * 7 -- 7 days in seconds

-- Parse plugin descriptions directly from paragraphs
local function parse_plugin_descriptions_from_paragraphs(html_content)
  local descriptions = {}
  local current_plugin = nil
  
  -- Process the HTML content to find paragraphs containing plugin names
  for paragraph in html_content:gmatch('<p>(.-)</p>') do
    -- Look for plugin name in the paragraph
    local plugin_name = paragraph:match('(llm%-[%w%-]+)')
    
    if plugin_name then
      -- Get the position of the plugin name in the paragraph
      local _, plugin_end = paragraph:find(plugin_name)
      
      if plugin_end then
        -- Extract everything after the plugin name as the description
        local description = paragraph:sub(plugin_end + 1)
        
        -- Clean up the description
        description = description:gsub("<[^>]+>", " ")  -- Replace HTML tags with spaces
        description = description:gsub("%s+", " ")      -- Normalize whitespace
        description = description:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace
        -- Remove any (available) or (installed) status indicators
        description = description:gsub("%(%s*available%s*%)", "")
        description = description:gsub("%(%s*installed%s*%)", "")
        description = description:gsub("%s+", " ")      -- Normalize whitespace again
        description = description:gsub("^%s*(.-)%s*$", "%1")  -- Trim again
        
        -- Store the description if it's not empty
        if description and description ~= "" then
          descriptions[plugin_name] = description
        end
      end
    end
  end
  
  return descriptions
end

-- Fallback function to provide hardcoded plugins when web fetching fails
local function get_hardcoded_plugins()
  local plugins = {}
  
  -- Local models
  plugins["llm-gguf"] = { name = "llm-gguf", description = "Run GGUF format local models", category = "Local models" }
  plugins["llm-mlx"] = { name = "llm-mlx", description = "Run models using Apple MLX framework", category = "Local models" }
  plugins["llm-ollama"] = { name = "llm-ollama", description = "Use Ollama models via API", category = "Local models" }
  plugins["llm-llamafile"] = { name = "llm-llamafile", description = "Run models via llamafile", category = "Local models" }
  plugins["llm-mlc"] = { name = "llm-mlc", description = "Run models with MLC", category = "Local models" }
  plugins["llm-gpt4all"] = { name = "llm-gpt4all", description = "Run models with GPT4All", category = "Local models" }
  plugins["llm-mpt30b"] = { name = "llm-mpt30b", description = "Run MPT-30B models", category = "Local models" }
  
  -- Remote APIs
  plugins["llm-mistral"] = { name = "llm-mistral", description = "Use Mistral AI API", category = "Remote APIs" }
  plugins["llm-gemini"] = { name = "llm-gemini", description = "Use Google Gemini API", category = "Remote APIs" }
  plugins["llm-anthropic"] = { name = "llm-anthropic", description = "Use Anthropic Claude API", category = "Remote APIs" }
  plugins["llm-command-r"] = { name = "llm-command-r", description = "Use Command R API", category = "Remote APIs" }
  plugins["llm-reka"] = { name = "llm-reka", description = "Use Reka API", category = "Remote APIs" }
  plugins["llm-perplexity"] = { name = "llm-perplexity", description = "Use Perplexity API", category = "Remote APIs" }
  plugins["llm-groq"] = { name = "llm-groq", description = "Use Groq API", category = "Remote APIs" }
  plugins["llm-grok"] = { name = "llm-grok", description = "Use xAI Grok API", category = "Remote APIs" }
  plugins["llm-anyscale-endpoints"] = { name = "llm-anyscale-endpoints", description = "Use Anyscale Endpoints API", category = "Remote APIs" }
  plugins["llm-replicate"] = { name = "llm-replicate", description = "Use Replicate API", category = "Remote APIs" }
  plugins["llm-fireworks"] = { name = "llm-fireworks", description = "Use Fireworks AI API", category = "Remote APIs" }
  plugins["llm-openrouter"] = { name = "llm-openrouter", description = "Use OpenRouter API", category = "Remote APIs" }
  plugins["llm-cohere"] = { name = "llm-cohere", description = "Use Cohere API", category = "Remote APIs" }
  plugins["llm-bedrock"] = { name = "llm-bedrock", description = "Use AWS Bedrock API", category = "Remote APIs" }
  plugins["llm-bedrock-anthropic"] = { name = "llm-bedrock-anthropic", description = "Use AWS Bedrock Anthropic models", category = "Remote APIs" }
  plugins["llm-bedrock-meta"] = { name = "llm-bedrock-meta", description = "Use AWS Bedrock Meta models", category = "Remote APIs" }
  plugins["llm-together"] = { name = "llm-together", description = "Use Together AI API", category = "Remote APIs" }
  plugins["llm-deepseek"] = { name = "llm-deepseek", description = "Use DeepSeek API", category = "Remote APIs" }
  plugins["llm-lambda-labs"] = { name = "llm-lambda-labs", description = "Use Lambda Labs API", category = "Remote APIs" }
  plugins["llm-venice"] = { name = "llm-venice", description = "Use Venice API", category = "Remote APIs" }
  
  -- Embedding models
  plugins["llm-sentence-transformers"] = { name = "llm-sentence-transformers", description = "Generate embeddings with sentence-transformers", category = "Embedding models" }
  plugins["llm-clip"] = { name = "llm-clip", description = "Generate embeddings with CLIP", category = "Embedding models" }
  plugins["llm-embed-jina"] = { name = "llm-embed-jina", description = "Generate embeddings with Jina", category = "Embedding models" }
  plugins["llm-embed-onnx"] = { name = "llm-embed-onnx", description = "Generate embeddings with ONNX", category = "Embedding models" }
  
  -- Extra commands
  plugins["llm-cmd"] = { name = "llm-cmd", description = "Run shell commands with LLM", category = "Extra commands" }
  plugins["llm-cmd-comp"] = { name = "llm-cmd-comp", description = "Command completion with LLM", category = "Extra commands" }
  plugins["llm-python"] = { name = "llm-python", description = "Run Python code with LLM", category = "Extra commands" }
  plugins["llm-cluster"] = { name = "llm-cluster", description = "Cluster text with LLM", category = "Extra commands" }
  plugins["llm-jq"] = { name = "llm-jq", description = "Process JSON with jq", category = "Extra commands" }
  
  -- Fragments and template loaders
  plugins["llm-templates-github"] = { name = "llm-templates-github", description = "Load templates from GitHub", category = "Fragments and template loaders" }
  plugins["llm-templates-fabric"] = { name = "llm-templates-fabric", description = "Load templates from Fabric", category = "Fragments and template loaders" }
  plugins["llm-fragments-github"] = { name = "llm-fragments-github", description = "Load fragments from GitHub", category = "Fragments and template loaders" }
  plugins["llm-hacker-news"] = { name = "llm-hacker-news", description = "Load content from Hacker News", category = "Fragments and template loaders" }
  
  -- Just for fun
  plugins["llm-markov"] = { name = "llm-markov", description = "Generate text with Markov chains", category = "Just for fun" }
  
  return plugins
end

-- Parse HTML content to extract plugin information
local function parse_plugins_html(html_content)
  local plugins = {}
  local current_category = nil
  
  -- Pattern to find category headers
  local category_patterns = {
    '<h2 id="([^"]+)">([^<]+)',
    '<h2[^>]*>([^<]+)',
    '## ([^#\r\n]+)'
  }
  
  -- Pattern to find plugin entries - specifically for the format in the LLM docs
  local plugin_patterns = {
    -- Markdown style patterns
    '- %*%*%[([^%]]+)%]%(([^%)]+)%)%*%*%s*(.-)<',
    '%*%*%[([^%]]+)%]%(([^%)]+)%)%*%*(.-)<',
    
    -- HTML style patterns with reference-external class
    '<a%s+class="reference%s+external"%s+href="([^"]+)">([^<]+)</a>(.-)<',
    '<strong><a%s+class="reference%s+external"%s+href="([^"]+)">([^<]+)</a></strong>(.-)<',
    
    -- HTML style patterns with strong tags
    '<li>.-<strong>%[([^%]]+)%]%(([^%)]+)%)</strong>(.-)</li>',
    '<li>.-<strong>%[([^%]]+)%]%(([^%)]+)%)</strong>(.-)</',
    '<p>.-<strong>%[([^%]]+)%]%(([^%)]+)%)</strong>(.-)</p>',
    
    -- Additional patterns for different HTML structures
    '<li>.-<a%s+href="([^"]+)".->(llm%-[%w%-]+)</a>(.-)</li>',
    '<li>.-<strong><a%s+href="([^"]+)".->(llm%-[%w%-]+)</a></strong>(.-)</li>',
    
    -- Direct paragraph patterns
    '<p>.-<a[^>]+>(llm%-[%w%-]+)</a>(.-)</p>',
    '<p>.-<strong><a[^>]+>(llm%-[%w%-]+)</a></strong>(.-)</p>',
    '<p>.-<code>(llm%-[%w%-]+)</code>(.-)</p>',
    '<p>.-<strong>(llm%-[%w%-]+)</strong>(.-)</p>',
    '<p>(llm%-[%w%-]+)(.-)</p>'
  }
  
  -- Debug info
  local categories_found = 0
  local plugins_found = 0
  local debug_lines = {}
  
  -- Process the HTML line by line
  for line in html_content:gmatch("[^\r\n]+") do
    -- Add to debug lines (limited to avoid excessive logging)
    if #debug_lines < 100 then
      table.insert(debug_lines, line)
    end
    -- Check for category using multiple patterns
    local category_found = false
    for _, pattern in ipairs(category_patterns) do
      local category_id, category_name = line:match(pattern)
      if category_name then
        current_category = category_name:gsub("[#]", ""):gsub("^%s*(.-)%s*$", "%1")
        categories_found = categories_found + 1
        category_found = true
        break
      elseif category_id and not category_name then
        -- Some patterns only capture one group
        current_category = category_id:gsub("[#]", ""):gsub("^%s*(.-)%s*$", "%1")
        categories_found = categories_found + 1
        category_found = true
        break
      end
    end
    
    -- If we found a category, continue to next line
    if category_found then
      goto continue
    end
    
    -- Check for plugin using multiple patterns
    if current_category then
      for _, pattern in ipairs(plugin_patterns) do
        local plugin_name, plugin_url, description = line:match(pattern)
        
        -- Handle patterns where URL and name are swapped
        if plugin_name and plugin_name:match("^http") and plugin_url and plugin_url:match("^llm%-") then
          plugin_name, plugin_url = plugin_url, plugin_name
        end
        
        if plugin_name and current_category then
          -- Clean up the plugin name to get the actual package name
          local package_name = plugin_name:match("llm%-[%w%-]+")
          if package_name then
            -- Extract description - clean up HTML and whitespace
            description = description or ""
            description = description:gsub("<[^>]+>", "")  -- Remove HTML tags
            description = description:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace
            
            -- If description is empty, try to extract from the whole paragraph
            if description == "" and line:match('<p>') then
              local p_content = line:match('<p>(.-)</p>')
              if p_content then
                -- Remove the plugin name and any HTML tags
                description = p_content:gsub(package_name, "")
                description = description:gsub("<[^>]+>", "")
                description = description:gsub("^%s*(.-)%s*$", "%1")
              end
            end
            
            plugins[package_name] = {
              name = package_name,
              description = description,
              category = current_category,
              url = plugin_url or ""
            }
            plugins_found = plugins_found + 1
            break
          end
        end
      end
    end
    
    ::continue::
  end
  
  -- If we found plugins, log success
  if plugins_found > 0 then
    vim.notify(string.format("Successfully parsed %d categories and %d plugins", 
               categories_found, plugins_found), vim.log.levels.INFO)
  else
    vim.notify("Failed to parse any plugins from HTML content", vim.log.levels.WARN)
    
    -- Save the first few lines for debugging
    local debug_sample = table.concat(debug_lines, "\n")
    local debug_sample_file = utils.get_config_path('plugins_html_sample.txt')
    local df = io.open(debug_sample_file, "w")
    if df then
      df:write(debug_sample)
      df:close()
      vim.notify("Saved HTML sample to " .. debug_sample_file, vim.log.levels.INFO)
    end
  end
  
  return plugins
end

-- Get the last successful cache or hardcoded plugins
local function get_last_successful_cache()
  -- Try to load from cache first
  local file = io.open(cache_file, "r")
  if file then
    local content = file:read("*a")
    file:close()
    
    local success, cache_data = pcall(vim.fn.json_decode, content)
    if success and cache_data.plugins and vim.tbl_count(cache_data.plugins) > 0 then
      vim.notify("Using last successful cache as fallback", vim.log.levels.INFO)
      return cache_data.plugins
    end
  end
  
  -- If no cache or invalid cache, use hardcoded plugins
  return get_hardcoded_plugins()
end

-- Alternative HTML parsing approach using a state machine
local function parse_plugins_html_alternative(html_content)
  local plugins = {}
  local current_category = nil
  local in_list = false
  local categories_found = 0
  local plugins_found = 0
  
  -- Process the HTML line by line
  for line in html_content:gmatch("[^\r\n]+") do
    -- Check for category headers (h2 tags)
    local category = line:match('<h2[^>]*>(.-)</h2>') or 
                     line:match('<h2[^>]*>(.+)') or
                     line:match('## ([^#\r\n]+)')
    
    if category then
      current_category = category:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1")
      categories_found = categories_found + 1
      in_list = false
    end
    
    -- Check for list items or paragraphs that might contain plugins
    if current_category then
      -- Look for list start
      if line:match('<ul') or line:match('<ol') then
        in_list = true
      end
      
      -- Look for list end
      if line:match('</ul>') or line:match('</ol>') then
        in_list = false
      end
      
      -- Look for plugin entries in list items or paragraphs
      if in_list or line:match('^%s*-%s') or line:match('<p>') then
        -- Try to extract plugin info using various patterns
        local plugin_name, plugin_url, description
        
        -- Pattern for markdown style: **[llm-name](url)** description
        plugin_name, plugin_url = line:match('%*%*%[([^%]]+)%]%(([^%)]+)%)%*%*')
        if plugin_name then
          description = line:match('%*%*%[.-%]%(.-%)%*%*%s*(.+)')
        end
        
        -- Pattern for HTML style: <strong>[llm-name](url)</strong> description
        if not plugin_name then
          plugin_name, plugin_url = line:match('<strong>%[([^%]]+)%]%(([^%)]+)%)</strong>')
          if plugin_name then
            description = line:match('<strong>%[.-%]%(.-%)</strong>%s*(.+)')
          end
        end
        
        -- Pattern for HTML style with reference-external class
        if not plugin_name then
          plugin_url, plugin_name = line:match('<a%s+class="reference%s+external"%s+href="([^"]+)">([^<]+)</a>')
          if plugin_name then
            description = line:match('<a%s+class="reference%s+external".->.-</a>%s*(.+)')
          end
        end
        
        -- Pattern for HTML style with nested strong and a tags
        if not plugin_name then
          plugin_url, plugin_name = line:match('<strong><a%s+href="([^"]+)".->(llm%-[%w%-]+)</a></strong>')
          if plugin_name then
            description = line:match('<strong><a.->.-</a></strong>%s*(.+)')
          end
        end
        
        -- Direct extraction of llm-* pattern from the line as last resort
        if not plugin_name then
          plugin_name = line:match('(llm%-[%w%-]+)')
          if plugin_name then
            -- Try to find a URL in the line
            plugin_url = line:match('href="([^"]+)"') or ""
            
            -- Try to extract description directly after the plugin name
            description = line:match('llm%-[%w%-]+[^<>]*(.+)')
            
            -- If no description found, try to extract from paragraph content
            if not description and line:match('<p>') then
              -- Get content between <p> tags
              local p_content = line:match('<p>(.-)</p>')
              if p_content then
                -- Find the position of the plugin name in the paragraph
                local _, plugin_end = p_content:find(plugin_name)
                if plugin_end then
                  -- Extract everything after the plugin name
                  description = p_content:sub(plugin_end + 1)
                end
              end
            end
          end
        end
        
        -- If we found a plugin name, process it
        if plugin_name then
          -- Clean up the plugin name to get the actual package name
          local package_name = plugin_name:match("llm%-[%w%-]+")
          if package_name then
            -- Clean up description
            description = description or ""
            description = description:gsub("<[^>]+>", "")  -- Remove HTML tags
            description = description:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace
            
            plugins[package_name] = {
              name = package_name,
              description = description,
              category = current_category,
              url = plugin_url or ""
            }
            plugins_found = plugins_found + 1
          end
        end
      end
    end
  end
  
  vim.notify(string.format("Alternative parser: found %d categories and %d plugins", 
             categories_found, plugins_found), vim.log.levels.INFO)
  
  return plugins
end

-- Fetch plugins from the LLM documentation website
local function fetch_plugins_from_website()
  local url = "https://llm.datasette.io/en/stable/plugins/directory.html"
  
  -- Use curl with more options for better reliability
  local cmd = string.format("curl -s -L -f -m 30 --connect-timeout 10 %s", url)
  
  local result = utils.safe_shell_command(cmd, "Failed to fetch plugin directory")
  
  if not result then
    vim.notify("Failed to fetch plugin information from website, using cached data", vim.log.levels.WARN)
    return get_last_successful_cache()
  end
  
  -- Save raw HTML for debugging
  local debug_file = utils.get_config_path('plugins_html_debug.txt')
  local df = io.open(debug_file, "w")
  if df then
    df:write(result)
    df:close()
  end
  
  -- Check if we got HTML content
  if not result:match("<html") and not result:match("<!DOCTYPE") then
    vim.notify("Received non-HTML response from website", vim.log.levels.WARN)
    return get_last_successful_cache()
  end
  
  -- Try all parsing methods in sequence until one works
  local plugins = parse_plugins_html(result)
  
  -- If the first method didn't find any plugins, try the alternative method
  if vim.tbl_count(plugins) == 0 then
    vim.notify("First parsing method found no plugins, trying alternative method...", vim.log.levels.INFO)
    plugins = parse_plugins_html_alternative(result)
  end
  
  -- If still no plugins, try the robust method
  if vim.tbl_count(plugins) == 0 then
    vim.notify("Alternative parsing method found no plugins, trying robust method...", vim.log.levels.INFO)
    plugins = parse_plugins_html_robust(result)
  end
  
  -- Get direct paragraph descriptions to enhance existing descriptions
  local paragraph_descriptions = parse_plugin_descriptions_from_paragraphs(result)
  
  -- Merge paragraph descriptions with existing plugins
  for plugin_name, description in pairs(paragraph_descriptions) do
    if plugins[plugin_name] then
      -- If the existing description is empty or shorter than the paragraph description,
      -- use the paragraph description
      if plugins[plugin_name].description == "" or 
         (#plugins[plugin_name].description < #description and #description > 10) then
        plugins[plugin_name].description = description
      end
    end
  end
  
  -- Check if we parsed any plugins with any method
  if vim.tbl_count(plugins) == 0 then
    vim.notify("No plugins found in HTML content with any parsing method, using cached data", vim.log.levels.WARN)
    return get_last_successful_cache()
  end
  
  -- Save to cache
  local cache_data = {
    timestamp = os.time(),
    plugins = plugins
  }
  
  -- Write to cache file
  local file = io.open(cache_file, "w")
  if file then
    file:write(vim.fn.json_encode(cache_data))
    file:close()
    vim.notify("Updated plugins cache with " .. vim.tbl_count(plugins) .. " plugins", vim.log.levels.INFO)
  end
  
  return plugins
end

-- Load plugins from cache if available and not expired
local function load_plugins_from_cache()
  local file = io.open(cache_file, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*a")
  file:close()
  
  local success, cache_data = pcall(vim.fn.json_decode, content)
  if not success or not cache_data.timestamp or not cache_data.plugins then
    return nil
  end
  
  -- Check if cache is expired
  if os.time() - cache_data.timestamp > cache_expiry then
    return nil
  end
  
  return cache_data.plugins
end

-- Cache for the current session to avoid multiple fetches
local plugins_cache = nil

-- Get all plugins with descriptions
function M.get_plugins_with_descriptions()
  -- If we already have plugins in memory for this session, use them
  if plugins_cache and vim.tbl_count(plugins_cache) > 0 then
    return plugins_cache
  end
  
  -- Try to load from disk cache first
  local disk_cache = load_plugins_from_cache()
  if disk_cache and vim.tbl_count(disk_cache) > 0 then
    plugins_cache = disk_cache
    return plugins_cache
  end
  
  -- If no cache, fetch from website
  local plugins = fetch_plugins_from_website()
  plugins_cache = plugins
  
  return plugins
end

-- Force refresh the plugin cache
function M.refresh_plugins_cache()
  vim.notify("Fetching latest plugin directory from llm.datasette.io...", vim.log.levels.INFO)
  -- Clear the in-memory cache
  plugins_cache = nil
  
  local plugins = fetch_plugins_from_website()
  if plugins and vim.tbl_count(plugins) > 0 then
    -- Update the in-memory cache
    plugins_cache = plugins
    vim.notify("Successfully refreshed plugin directory with " .. vim.tbl_count(plugins) .. " plugins", vim.log.levels.INFO)
  else
    vim.notify("Failed to refresh plugin directory, using cached data", vim.log.levels.WARN)
  end
  return plugins
end

-- Parse the debug HTML file (useful for troubleshooting)
function M.parse_debug_html()
  local debug_file = utils.get_config_path('plugins_html_debug.txt')
  local file = io.open(debug_file, "r")
  
  if not file then
    vim.notify("Debug HTML file not found", vim.log.levels.ERROR)
    return {}
  end
  
  local content = file:read("*a")
  file:close()
  
  vim.notify("Parsing debug HTML file with all methods...", vim.log.levels.INFO)
  
  -- Try all parsing methods
  local plugins_standard = parse_plugins_html(content)
  local plugins_alternative = parse_plugins_html_alternative(content)
  local plugins_robust = parse_plugins_html_robust(content)
  
  vim.notify(string.format("Standard parser: found %d plugins", vim.tbl_count(plugins_standard)), vim.log.levels.INFO)
  vim.notify(string.format("Alternative parser: found %d plugins", vim.tbl_count(plugins_alternative)), vim.log.levels.INFO)
  vim.notify(string.format("Robust parser: found %d plugins", vim.tbl_count(plugins_robust)), vim.log.levels.INFO)
  
  -- Use the method that found the most plugins
  local plugins = plugins_standard
  if vim.tbl_count(plugins_alternative) > vim.tbl_count(plugins) then
    plugins = plugins_alternative
  end
  if vim.tbl_count(plugins_robust) > vim.tbl_count(plugins) then
    plugins = plugins_robust
  end
  
  if vim.tbl_count(plugins) == 0 then
    vim.notify("No plugins found in debug HTML file with any method", vim.log.levels.WARN)
    
    -- Try to extract sections to see what's in the HTML
    local sections = {}
    local current_section = nil
    
    for line in content:gmatch("[^\r\n]+") do
      -- Look for section headers
      local section_header = line:match('<h2[^>]*>(.-)</h2>') or line:match('<h2[^>]*>(.+)')
      if section_header then
        current_section = section_header:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1")
        sections[current_section] = {}
      elseif current_section and line:match('<li') then
        table.insert(sections[current_section], line)
      end
    end
    
    -- Log what sections we found
    local sections_info = "Found sections: "
    for section, _ in pairs(sections) do
      sections_info = sections_info .. section .. ", "
    end
    vim.notify(sections_info, vim.log.levels.INFO)
    
    -- Save detailed debug info
    local debug_analysis = utils.get_config_path('plugins_html_analysis.txt')
    local df = io.open(debug_analysis, "w")
    if df then
      df:write("HTML Analysis:\n\n")
      for section, lines in pairs(sections) do
        df:write("Section: " .. section .. "\n")
        df:write("Sample lines:\n")
        for i, line in ipairs(lines) do
          if i <= 3 then -- Just show a few sample lines
            df:write(line .. "\n")
          end
        end
        df:write("\n")
      end
      df:close()
      vim.notify("Saved HTML analysis to " .. debug_analysis, vim.log.levels.INFO)
    end
  else
    vim.notify("Found " .. vim.tbl_count(plugins) .. " plugins in debug HTML file", vim.log.levels.INFO)
  end
  
  return plugins
end

-- More robust HTML parsing function that processes the entire document
local function parse_plugins_html_robust(html_content)
  local plugins = {}
  local categories = {}
  local current_category = nil
  
  -- First pass: identify all h2 sections (categories)
  for section in html_content:gmatch('<h2[^>]*>.-</h2>.-<[hH][23]') do
    -- Extract category name
    local category_name = section:match('<h2[^>]*>(.-)</h2>')
    if category_name then
      -- Clean up HTML tags from category name
      category_name = category_name:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1")
      
      -- Store the section content
      table.insert(categories, {
        name = category_name,
        content = section
      })
    end
  end
  
  -- Handle the last section (which won't end with another h2/h3)
  local last_section = html_content:match('(<h2[^>]*>.-</h2>.-)$')
  if last_section then
    local category_name = last_section:match('<h2[^>]*>(.-)</h2>')
    if category_name then
      category_name = category_name:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1")
      table.insert(categories, {
        name = category_name,
        content = last_section
      })
    end
  end
  
  -- Second pass: extract plugins from each category
  for _, category in ipairs(categories) do
    -- Look for paragraphs and list items in this category
    for item in category.content:gmatch('<[pli][^>]*>(.-)</%1>') do
      -- Try to find plugin name and URL
      local plugin_name, plugin_url, description
      
      -- Look for llm-* pattern in the item
      plugin_name = item:match('(llm%-[%w%-]+)')
      
      if plugin_name then
        -- Try to extract URL - look for href attribute
        plugin_url = item:match('href="([^"]+)"')
        
        -- Extract description directly from the paragraph content
        -- First try to find the description after the plugin name in the same paragraph
        description = item:match(plugin_name .. '[^<>]*(.+)')
        
        if not description or description == "" then
          -- If no description found after plugin name, use the whole paragraph content
          description = item
          -- Clean up the description
          description = description:gsub('<[^>]+>', ' ') -- Replace tags with spaces
          description = description:gsub('llm%-[%w%-]+', '') -- Remove plugin name
          description = description:gsub('http[s]?://[^%s]+', '') -- Remove URLs
        else
          -- Clean up the extracted description
          description = description:gsub('<[^>]+>', ' ') -- Replace tags with spaces
        end
        
        -- Final cleanup
        description = description:gsub('%s+', ' ') -- Normalize whitespace
        description = description:gsub('^%s*(.-)%s*$', '%1') -- Trim
        
        -- Store the plugin
        plugins[plugin_name] = {
          name = plugin_name,
          description = description,
          category = category.name,
          url = plugin_url or ""
        }
      end
    end
  end
  
  vim.notify(string.format("Robust parser: found %d categories and %d plugins", 
             #categories, vim.tbl_count(plugins)), vim.log.levels.INFO)
  
  return plugins
end

-- Debug function to manually test pattern matching
function M.test_pattern_matching()
  local debug_file = utils.get_config_path('plugins_html_debug.txt')
  local file = io.open(debug_file, "r")
  
  if not file then
    vim.notify("Debug HTML file not found", vim.log.levels.ERROR)
    return
  end
  
  local content = file:read("*a")
  file:close()
  
  -- Test patterns on the content
  local patterns = {
    '- %*%*%[([^%]]+)%]%(([^%)]+)%)%*%*%s*(.-)<',
    '<li>.-<strong>%[([^%]]+)%]%(([^%)]+)%)</strong>(.-)</li>',
    '<li>.-<strong>%[([^%]]+)%]%(([^%)]+)%)</strong>(.-)</',
    '%*%*%[([^%]]+)%]%(([^%)]+)%)%*%*(.-)<',
    '<p>.-<strong>%[([^%]]+)%]%(([^%)]+)%)</strong>(.-)</p>'
  }
  
  local results = {}
  
  for i, pattern in ipairs(patterns) do
    results[i] = {
      pattern = pattern,
      matches = {}
    }
    
    for line in content:gmatch("[^\r\n]+") do
      local name, url, desc = line:match(pattern)
      if name and name:match("llm%-[%w%-]+") then
        table.insert(results[i].matches, {
          name = name,
          url = url,
          desc = desc
        })
      end
    end
  end
  
  -- Save results
  local results_file = utils.get_config_path('pattern_test_results.txt')
  local rf = io.open(results_file, "w")
  if rf then
    rf:write("Pattern Matching Test Results:\n\n")
    
    for i, result in ipairs(results) do
      rf:write("Pattern " .. i .. ": " .. result.pattern .. "\n")
      rf:write("Matches found: " .. #result.matches .. "\n")
      
      for j, match in ipairs(result.matches) do
        if j <= 5 then -- Limit to 5 examples
          rf:write(string.format("  %d. Name: %s, URL: %s\n", j, match.name, match.url))
        end
      end
      rf:write("\n")
    end
    
    rf:close()
    vim.notify("Saved pattern test results to " .. results_file, vim.log.levels.INFO)
  end
end

-- Get plugin names grouped by category
function M.get_plugins_by_category()
  local plugins_data = M.get_plugins_with_descriptions()
  local categories = {}
  
  for _, plugin in pairs(plugins_data) do
    if not categories[plugin.category] then
      categories[plugin.category] = {}
    end
    table.insert(categories[plugin.category], plugin.name)
  end
  
  return categories
end


-- Get all plugin names as a flat list
function M.get_all_plugin_names()
  local plugins_data = M.get_plugins_with_descriptions()
  local names = {}
  
  -- Check if we have any plugins
  if not plugins_data or vim.tbl_count(plugins_data) == 0 then
    vim.notify("No plugins found in data, using fallback", vim.log.levels.WARN)
    plugins_data = get_hardcoded_plugins()
  end
  
  for name, _ in pairs(plugins_data) do
    table.insert(names, name)
  end
  
  -- If we still have no plugins, add a minimal set
  if #names == 0 then
    vim.notify("Falling back to minimal plugin set", vim.log.levels.WARN)
    table.insert(names, "llm-gguf")
    table.insert(names, "llm-mistral")
    table.insert(names, "llm-anthropic")
    table.insert(names, "llm-gemini")
  end
  
  return names
end

return M
