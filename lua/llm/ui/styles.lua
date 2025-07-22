-- llm/styles.lua - Centralized styling for llm-nvim
-- License: Apache 2.0

local M = {}

-- Color palette
M.colors = {
  -- Base colors
  blue = "#61afef",
  cyan = "#56b6c2",
  green = "#98c379",
  red = "#e06c75",
  purple = "#c678dd",
  yellow = "#e5c07b",
  orange = "#d19a66",
  gray = "#abb2bf",
  dark_gray = "#3b4048",
  
  -- Semantic colors (can be mapped to base colors)
  header = "#61afef",
  subheader = "#56b6c2",
  section = "#c678dd",
  action = "#e5c07b",
  content = "#abb2bf",
  success = "#98c379",
  error = "#e06c75",
  divider = "#3b4048",
  keybinding = "#e5c07b",
}

-- Highlight groups
M.highlights = {
  -- Common highlight groups
  Header = { fg = M.colors.header, style = "bold" },
  SubHeader = { fg = M.colors.subheader, style = "bold" },
  Section = { fg = M.colors.section, style = "bold" },
  Action = { fg = M.colors.action, style = "bold" },
  Divider = { fg = M.colors.divider },
  Content = { fg = M.colors.content },
  Success = { fg = M.colors.success, style = "bold" },
  Error = { fg = M.colors.error },
  Custom = { fg = M.colors.yellow, style = "bold" },
  Keybinding = { fg = M.colors.keybinding, style = "bold" },
  NavKeybinding = { fg = M.colors.cyan, style = "bold" }, -- Added for navigation keys

  -- Checkbox and status states
  CheckboxInstalled = { fg = M.colors.success, style = "bold" },
  CheckboxAvailable = { fg = M.colors.error },
  Installed = { fg = M.colors.success, style = "bold", bg = "#333333" },
  NotInstalled = { fg = M.colors.error, style = "bold", bg = "#1a1a1a" },
  
  -- Model-specific highlights
  ModelOpenAI = { fg = M.colors.cyan },
  ModelAnthropic = { fg = M.colors.green },
  ModelMistral = { fg = M.colors.purple },
  ModelGemini = { fg = M.colors.yellow },
  ModelGroq = { fg = M.colors.blue },
  ModelLocal = { fg = M.colors.orange },
  ModelDefault = { fg = M.colors.success, style = "bold" },
  ModelAlias = { fg = M.colors.purple },
  
  -- Fragment-specific highlights
  FragmentHash = { fg = M.colors.blue },
  FragmentSource = { fg = M.colors.green },
  FragmentAliases = { fg = M.colors.purple },
  FragmentDate = { fg = M.colors.cyan },
  FragmentContent = { fg = M.colors.content },
  
  -- Key-specific highlights
  KeyAvailable = { fg = M.colors.success },
  KeyMissing = { fg = M.colors.error },
  KeyAction = { link = "LLMCustom" },
  
  -- Schema-specific highlights (using common highlight groups)
  SchemaHeader = { link = "LLMHeader" },
  SchemaSection = { link = "LLMSubHeader" },
  SchemaContent = { link = "LLMContent" },
  SchemaFooter = { link = "LLMAction" },
  SchemaName = { fg = M.colors.yellow, style = "bold" },
  SchemaId = { fg = M.colors.blue, style = "bold" },
  Success = { fg = M.colors.success, style = "bold" },
  Error = { fg = M.colors.error, style = "bold" },
  
  -- Template-specific highlights (using common highlight groups)
  TemplateHeader = { link = "LLMHeader" },
  TemplateSection = { link = "LLMSubHeader" },
  TemplateContent = { link = "LLMContent" },
  TemplateFooter = { link = "LLMAction" },
  TemplateName = { fg = M.colors.yellow, style = "bold" },
  
  -- Template-specific highlights
  TemplateHeader = { fg = M.colors.header, style = "bold" },
  TemplateSection = { fg = M.colors.section, style = "bold" },
  TemplateContent = { fg = M.colors.content },
  TemplateFooter = { fg = M.colors.action, style = "bold" },
  LoaderTitle = { fg = M.colors.purple, style = "bold" },
  LoaderUsage = { fg = M.colors.cyan },
}

-- Setup function to create all highlight groups
function M.setup_highlights()
  -- Create highlight commands
  local highlight_cmds = {}
  
  for name, attrs in pairs(M.highlights) do
    local cmd = "highlight default LLM" .. name
    
    if attrs.link then
      cmd = cmd .. " link=" .. attrs.link
    elseif attrs.fg then
      cmd = cmd .. " guifg=" .. attrs.fg
      
      if attrs.bg then
        cmd = cmd .. " guibg=" .. attrs.bg
      end
      
      if attrs.style then
        cmd = cmd .. " gui=" .. attrs.style
      end
    end
    
    table.insert(highlight_cmds, cmd)
  end
  
  -- Execute all highlight commands
  for _, cmd in ipairs(highlight_cmds) do
    -- Execute each command separately to avoid errors stopping the whole batch
    pcall(vim.cmd, cmd)
  end
end

-- Define syntax patterns for different UI elements
M.syntax_patterns = {
  -- Headers
  header = "syntax match LLMHeader /^#.*/",
  subheader = "syntax match LLMSubHeader /^##.*/",
  
  
  
  
  
  -- Action text
  action = "syntax match LLMAction /Press.*$/",
  
  -- Dividers
  divider = "syntax match LLMDivider /^─\\+$/",
  
  -- Custom items
  custom = "syntax match LLMCustom /\\[+\\].*/",
  
  -- Keybindings in brackets
  keybinding = "syntax match LLMKeybinding /\\[[a-z?]\\]/", -- Match action keys
  nav_keybinding = "syntax match LLMNavKeybinding /\\[[A-Z]\\]/", -- Match navigation keys (M, P, K, F, T, S)

  -- Section headers
  section = "syntax match LLMSection /^[A-Za-z][A-Za-z0-9 ]*:$/",
  
  -- Model-specific patterns
  model_openai = "syntax match LLMModelOpenAI /^OpenAI.*$\\|\\[ \\] OpenAI.*/",
  model_anthropic = "syntax match LLMModelAnthropic /^Anthropic.*$\\|\\[ \\] Anthropic.*/",
  model_mistral = "syntax match LLMModelMistral /^Mistral.*$\\|\\[ \\] Mistral.*/",
  model_gemini = "syntax match LLMModelGemini /^Gemini.*$\\|\\[ \\] Gemini.*/",
  model_groq = "syntax match LLMModelGroq /^Groq.*$\\|\\[ \\] Groq.*/",
  model_default = "syntax match LLMModelDefault /\\[✓\\].*/",
  
  -- Fragment-specific patterns
  fragment_hash = "syntax match LLMFragmentHash /^Fragment \\d\\+: [0-9a-f]\\+$/",
  fragment_source = "syntax match LLMFragmentSource /^  Source: .*$/",
  fragment_aliases = "syntax match LLMFragmentAliases /^  Aliases: .*$/",
  fragment_date = "syntax match LLMFragmentDate /^  Date: .*$/",
  fragment_content = "syntax match LLMFragmentContent /^  Content: .*$/",
  
  -- Key-specific patterns
  key_available = "syntax match LLMKeyAvailable /\\[✓\\].*/",
  key_missing = "syntax match LLMKeyMissing /\\[ \\].*/",
  key_action = "syntax match LLMCustom /^\\[+\\] Add custom key$/",
  
  -- Schema-specific patterns (using common highlight groups)
  schema_header = "syntax match LLMHeader /^# Schema:/",
  schema_section = "syntax match LLMSubHeader /^## .*$/",
  schema_footer = "syntax match LLMAction /^Press.*$/",
  schema_id = "syntax match LLMSchemaId /^Schema \\d\\+: [0-9a-f]\\+$/",
  schema_name = "syntax match LLMSchemaName /^  Name: .*$/",
  schema_description = "syntax match LLMContent /^  Description: .*$/",
  
  -- Template-specific patterns
  template_header = "syntax match LLMHeader /^# Template:/",
  template_section = "syntax match LLMSubHeader /^## .*$/",
  template_footer = "syntax match LLMAction /^Press.*$/",
  template_name = "syntax match LLMTemplateName /^Template \\d\\+: .*$/",
  template_description = "syntax match LLMContent /^  Description: .*$/",
  loader_title = "syntax match LLMLoaderTitle /^Loader \\d\\+: .*$/",
  loader_usage = "syntax match LLMLoaderUsage /^  Usage: .*$/",
}

-- Setup syntax highlighting for a buffer
function M.setup_buffer_syntax(buf)
  -- Apply common syntax patterns to the buffer
  for name, pattern in pairs(M.syntax_patterns) do
    -- Use pcall to catch any syntax errors
    local success, err = pcall(function()
      vim.api.nvim_buf_call(buf, function()
        vim.cmd(pattern)
      end)
    end)
    
    if not success and self.config.get('debug') then
      vim.notify("Syntax pattern error for " .. name .. ": " .. tostring(err), vim.log.levels.WARN)
    end
  end
end

-- Setup all styling for a buffer
function M.setup_buffer_styling(buf)
  -- Setup highlights
  M.setup_highlights()
  
  -- Setup syntax patterns
  M.setup_buffer_syntax(buf)
end

return M
