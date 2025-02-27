local M = {}

-- Version information
M.version = "0.5.0"

-- Utility functions for case transformations
local function to_snake_case(str)
  -- Normalize all inputs to a common form first
  -- Convert to lowercase 
  str = string.lower(str)
  -- Replace dashes and underscores with spaces
  str = string.gsub(str, "[-_]", " ")
  -- Insert spaces before capitals in camelCase
  str = string.gsub(str, "(%l)(%u)", "%1 %2")
  -- Replace all spaces with underscores
  return string.gsub(str, "%s+", "_")
end

local function to_kebab_case(str)
  -- Normalize all inputs to a common form first
  -- Convert to lowercase 
  str = string.lower(str)
  -- Replace underscores and dashes with spaces
  str = string.gsub(str, "[-_]", " ")
  -- Insert spaces before capitals in camelCase
  str = string.gsub(str, "(%l)(%u)", "%1 %2")
  -- Replace all spaces with dashes
  return string.gsub(str, "%s+", "-")
end

local function to_camel_case(str)
  -- Normalize all inputs to a common form first
  -- Convert to lowercase 
  str = string.lower(str)
  -- Replace dashes and underscores with spaces
  str = string.gsub(str, "[-_]", " ")
  
  -- Capitalize first letter of each word (except first)
  local result = string.gsub(" " .. str, "%s%w", function(match)
    return string.upper(match:sub(2))
  end)
  
  -- Keep the first character and remove the leading space
  result = string.sub(str, 1, 1) .. string.sub(result, 2)
  
  -- Remove all spaces
  return string.gsub(result, "%s+", "")
end

local function to_pascal_case(str)
  -- Normalize all inputs to a common form first
  -- Convert to lowercase 
  str = string.lower(str)
  -- Replace dashes and underscores with spaces
  str = string.gsub(str, "[-_]", " ")
  
  -- Capitalize first letter of each word
  local result = string.gsub(" " .. str, "%s%w", function(match)
    return string.upper(match:sub(2))
  end)
  
  -- Remove all spaces
  return string.gsub(result, "%s+", "")
end

local function to_upper_case(str)
  -- Normalize all inputs to a common form first
  -- Convert to lowercase 
  str = string.lower(str)
  -- Replace dashes and spaces with underscores
  str = string.gsub(str, "[-\\ ]", "_")
  -- Convert to uppercase
  return string.upper(str)
end

-- Test case transformation functions
local function test_case_transformations()
  local test_strings = {
    "test-string",
    "test_string",
    "testString",
    "TestString",
    "TEST_STRING",
    "Test String"
  }
  
  print("Testing case transformations:")
  for _, str in ipairs(test_strings) do
    print("\nInput: " .. str)
    print("  snake: " .. to_snake_case(str))
    print("  kebab: " .. to_kebab_case(str))
    print("  camel: " .. to_camel_case(str))
    print("  pascal: " .. to_pascal_case(str))
    print("  upper: " .. to_upper_case(str))
  end
end

local function transform_by_case_format(str, format)
  if format == "snake" then
    return to_snake_case(str)
  elseif format == "kebab" then
    return to_kebab_case(str)
  elseif format == "camel" then
    return to_camel_case(str)
  elseif format == "pascal" then
    return to_pascal_case(str)
  elseif format == "upper" then
    return to_upper_case(str)
  else
    return str
  end
end

-- Parse var format expressions ${var:format}
local function parse_var_format(var_expr)
  local var_name, format = var_expr:match("([^:]+):?(%w*)")
  return var_name, format
end

-- Get available snippets from the configured directory or plugin directory
local function get_snippets(opts)
  local snippets = {}
  opts = opts or {}
  
  -- Collect snippets from all configured directories
  local directories = {}
  
  -- Add user configured directory if it exists
  local user_snippet_dir = vim.fn.expand(opts.snippet_dir or "~/.config/nvim/snippets/multi-file")
  if vim.fn.isdirectory(user_snippet_dir) == 1 then
    table.insert(directories, user_snippet_dir)
  end
  
  -- Add plugin example directory
  local plugin_dir = vim.fn.fnamemodify(vim.api.nvim_get_runtime_file("lua/scaffolder/init.lua", false)[1], ":h:h:h")
  local example_dir = plugin_dir .. "/examples"
  if vim.fn.isdirectory(example_dir) == 1 then
    table.insert(directories, example_dir)
  end
  
  -- Collect snippets from all directories
  for _, dir in ipairs(directories) do
    local handle = vim.loop.fs_scandir(dir)
    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        
        if type == "file" and name:match("%.json$") then
          local snippet_path = dir .. "/" .. name
          
          -- Try to read the JSON file to get name and description
          local file = io.open(snippet_path, "r")
          if file then
            local content = file:read("*all")
            file:close()
            
            local ok, snippet_info = pcall(vim.json.decode, content)
            if ok and snippet_info then
              table.insert(snippets, {
                name = snippet_info.name or name:gsub("%.json$", ""),
                description = snippet_info.description or "",
                path = snippet_path,
                -- Store source to show in UI
                source = dir == example_dir and "plugin" or "user"
              })
            else
              -- If JSON parsing fails, just use the filename
              table.insert(snippets, {
                name = name:gsub("%.json$", ""),
                description = "",
                path = snippet_path,
                source = dir == example_dir and "plugin" or "user"
              })
            end
          end
        end
      end
    end
  end
  
  return snippets
end

-- Function to replace variables in content with format specifiers ${var:format}
local function replace_variables(content, vars)
  if type(content) ~= "string" then return content end
  
  -- Replace ${var:format} or ${var} patterns
  return content:gsub("%${([^}]+)}", function(var_expr)
    local var_name, format = parse_var_format(var_expr)
    
    -- Get the base value
    local value = vars[var_name]
    if not value then
      return "${" .. var_expr .. "}" -- Keep the original if variable not found
    end
    
    -- Apply the format if specified
    if format and format ~= "" then
      return transform_by_case_format(value, format)
    else
      return value
    end
  end)
end

-- Function to generate a preview of what files will be created
local function generate_file_preview(snippet_path, name, root_dir)
  local file = io.open(snippet_path, "r")
  if not file then
    return "Could not read snippet file"
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Parse the JSON
  local ok, snippet = pcall(vim.json.decode, content)
  if not ok or not snippet then
    return "Failed to parse snippet JSON"
  end
  
  -- Check for folder case preference
  local folder_case = snippet.folder_case or "original"
  
  -- Format folder name according to preference
  local folder_name = name
  if folder_case == "snake" then
    folder_name = to_snake_case(name)
  elseif folder_case == "kebab" then
    folder_name = to_kebab_case(name)
  elseif folder_case == "camel" then
    folder_name = to_camel_case(name)
  elseif folder_case == "pascal" then
    folder_name = to_pascal_case(name)
  elseif folder_case == "upper" then
    folder_name = to_upper_case(name)
  elseif folder_case == "lower" then
    folder_name = string.lower(name)
  end
  
  -- Prepare variables
  local variables = {
    name = name,
    folder_name = folder_name,
    Name = to_pascal_case(name),
    name_snake = to_snake_case(name),
    name_kebab = to_kebab_case(name),
    name_camel = to_camel_case(name),
    NAME = to_upper_case(name)
  }
  
  -- Generate preview of files
  local preview = "Files to be created in " .. (root_dir or "current directory") .. ":\n\n"
  for _, file_entry in ipairs(snippet.files or {}) do
    local file_path = replace_variables(file_entry.path, variables)
    if root_dir then
      file_path = root_dir .. "/" .. file_path
    end
    preview = preview .. "  • " .. file_path .. "\n"
  end
  
  return preview, snippet
end

-- Function to generate file preview from snippet data and name
local function preview_from_snippet_data(snippet_data, name, root_dir)
  if not snippet_data then return "No snippet data available" end
  
  -- Check for folder case preference
  local folder_case = snippet_data.folder_case or "original"
  local name_value = name or "example"
  
  -- Format folder name according to preference
  local folder_name = name_value
  if folder_case == "snake" then
    folder_name = to_snake_case(name_value)
  elseif folder_case == "kebab" then
    folder_name = to_kebab_case(name_value)
  elseif folder_case == "camel" then
    folder_name = to_camel_case(name_value)
  elseif folder_case == "pascal" then
    folder_name = to_pascal_case(name_value)
  elseif folder_case == "upper" then
    folder_name = to_upper_case(name_value)
  elseif folder_case == "lower" then
    folder_name = string.lower(name_value)
  end
  
  -- Prepare variables
  local variables = {
    name = name_value,
    folder_name = folder_name,
    Name = to_pascal_case(name_value),
    name_snake = to_snake_case(name_value),
    name_kebab = to_kebab_case(name_value),
    name_camel = to_camel_case(name_value),
    NAME = to_upper_case(name_value)
  }
  
  -- Generate preview of files
  local preview = "Files to be created in " .. (root_dir or "current directory") .. ":\n\n"
  for _, file_entry in ipairs(snippet_data.files or {}) do
    local file_path = replace_variables(file_entry.path, variables)
    if root_dir then
      file_path = root_dir .. "/" .. file_path
    end
    preview = preview .. "  • " .. file_path .. "\n"
  end
  
  -- Add variable preview section
  preview = preview .. "\n\nName transformations:\n"
  preview = preview .. "  • PascalCase: " .. variables.Name .. "\n"
  preview = preview .. "  • snake_case: " .. variables.name_snake .. "\n"
  preview = preview .. "  • kebab-case: " .. variables.name_kebab .. "\n"
  preview = preview .. "  • camelCase: " .. variables.name_camel .. "\n"
  preview = preview .. "  • UPPER_CASE: " .. variables.NAME .. "\n"
  
  return preview
end

-- Function to create directories and files based on snippet
local function create_from_snippet(snippet_path, name, root_dir, opts)
  -- Read the snippet JSON file
  local file = io.open(snippet_path, "r")
  if not file then
    vim.notify("Could not open snippet file: " .. snippet_path, vim.log.levels.ERROR)
    return
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Parse the JSON
  local ok, snippet = pcall(vim.json.decode, content)
  if not ok or not snippet then
    vim.notify("Failed to parse snippet JSON", vim.log.levels.ERROR)
    return
  end
  
  -- Check for folder name case preference in the snippet
  local folder_case = snippet.folder_case or "original"
  
  -- Format the name for folder according to preference
  local folder_name = name
  if folder_case == "snake" then
    folder_name = to_snake_case(name)
  elseif folder_case == "kebab" then
    folder_name = to_kebab_case(name)
  elseif folder_case == "camel" then
    folder_name = to_camel_case(name)
  elseif folder_case == "pascal" then
    folder_name = to_pascal_case(name)
  elseif folder_case == "upper" then
    folder_name = to_upper_case(name)
  elseif folder_case == "lower" then
    folder_name = string.lower(name)
  end
  
  -- Prepare variables
  local variables = {
    name = name,
    folder_name = folder_name, -- Add the folder name with correct casing
    -- Add compatibility with old code that uses these fixed names
    Name = to_pascal_case(name),
    name_snake = to_snake_case(name),
    name_kebab = to_kebab_case(name),
    name_camel = to_camel_case(name),
    NAME = to_upper_case(name)
  }
  
  -- Keep track of created files for summary
  local created_files = {}
  local created_dirs = {}
  
  -- Create files from the snippet
  for _, file_entry in ipairs(snippet.files or {}) do
    -- Replace variables in file path
    local file_path = replace_variables(file_entry.path, variables)
    
    -- Prepend the root directory if specified
    if root_dir then
      file_path = root_dir .. "/" .. file_path
    end
    
    -- Create parent directories
    local dir_path = vim.fn.fnamemodify(file_path, ":h")
    vim.fn.mkdir(dir_path, "p")
    table.insert(created_dirs, dir_path)
    
    -- Replace variables in file content
    local file_content = replace_variables(file_entry.content or "", variables)
    
    -- Create the file (only if there's content or it's explicitly a file)
    if file_content ~= "" or not file_path:match("/$") then
      local new_file = io.open(file_path, "w")
      if new_file then
        new_file:write(file_content)
        new_file:close()
        table.insert(created_files, file_path)
      else
        vim.notify("Failed to create file: " .. file_path, vim.log.levels.ERROR)
      end
    else
      -- It's a directory (ending with /)
      table.insert(created_dirs, file_path)
    end
  end
  
  -- Only show summary message at the end for cleaner output
  if #created_files > 0 then
    vim.notify("Created " .. #created_files .. " files from snippet: " .. (snippet.name or "unnamed"), vim.log.levels.INFO)
  end
end

-- Function to format snippet display in FZF
local function format_snippet_entry(snippet)
  local source_label = snippet.source == "plugin" and "[plugin]" or "[user]"
  local description = snippet.description and (" - " .. snippet.description) or ""
  return string.format("%s %s%s", source_label, snippet.name, description)
end

-- Extract snippet name from formatted entry
local function extract_snippet_name(entry)
  -- Remove the [plugin] or [user] prefix and description
  return entry:match("%[%w+%] ([^%-]+)") or entry
end

-- Improved mini.files detection using MiniFiles API
local function is_mini_files_open()
  -- First check if the mini.files module is available
  local has_mini_files, mini_files = pcall(require, "mini.files")
  if not has_mini_files then
    return false
  end
  
  -- Use MiniFiles.get_explorer_state() if available (newer versions)
  if mini_files.get_explorer_state then
    local explorer_state = mini_files.get_explorer_state()
    return explorer_state ~= nil
  end
  
  -- Fallback to checking for visible buffers with mini_files local variable
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local ok, has_mini_files = pcall(vim.api.nvim_buf_get_var, buf, "mini_files")
      if ok and has_mini_files then
        return true
      end
    end
  end
  
  return false
end

-- Get current directory from mini.files
local function get_mini_files_current_dir()
  local has_mini_files, mini_files = pcall(require, "mini.files")
  if not has_mini_files then
    return nil
  end
  
  -- Use MiniFiles.get_explorer_state() if available
  if mini_files.get_explorer_state then
    local explorer_state = mini_files.get_explorer_state()
    if explorer_state and explorer_state.windows and #explorer_state.windows > 0 then
      local win_data = explorer_state.windows[explorer_state.depth_focus]
      if win_data and win_data.path then
        return win_data.path
      end
    end
  end
  
  -- Fallback to checking buffer variables
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local ok, mini_files_data = pcall(vim.api.nvim_buf_get_var, buf, "mini_files")
      if ok and mini_files_data and mini_files_data.current_dir then
        return mini_files_data.current_dir
      end
    end
  end
  
  -- Fallback to current directory
  return vim.fn.getcwd()
end

-- Show version information
function M.show_version()
  local msg = string.format("Scaffolder.nvim v%s", M.version)
  vim.notify(msg, vim.log.levels.INFO)
  return msg
end

-- Function to prompt user for directory selection
local function prompt_for_directory(callback)
  -- Default to current working directory
  local default_dir = vim.fn.getcwd()
  
  vim.ui.input({
    prompt = "Enter directory path: ",
    default = default_dir,
    completion = "dir",
    highlight = function()
      -- Put user in insert mode after the prompt appears
      vim.schedule(function() vim.cmd("startinsert") end)
    end,
  }, function(input)
    if not input or input == "" then
      return
    end
    
    -- Expand path and resolve ~
    local expanded_path = vim.fn.expand(input)
    
    -- Check if directory exists
    if vim.fn.isdirectory(expanded_path) == 0 then
      -- Ask to create the directory
      vim.ui.input({
        prompt = "Directory doesn't exist. Create it? (y/n): ",
        highlight = function()
          -- Put user in insert mode after the prompt appears
          vim.schedule(function() vim.cmd("startinsert") end)
        end,
      }, function(choice)
        if choice == "y" then
          -- Create directory
          local success = vim.fn.mkdir(expanded_path, "p")
          if success == 1 then
            vim.notify("Created directory: " .. expanded_path, vim.log.levels.INFO)
            callback(expanded_path)
          else
            vim.notify("Failed to create directory: " .. expanded_path, vim.log.levels.ERROR)
          end
        end
      end)
    else
      callback(expanded_path)
    end
  end)
end

-- Create a fancy floating window with content
local function create_floating_window(content, opts)
  local width = opts.width or 80
  local height = opts.height or 20
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  
  -- Calculate position
  local ui = vim.api.nvim_list_uis()[1]
  local win_width = math.min(width, ui.width - 4)
  local win_height = math.min(height, ui.height - 4)
  
  local row = math.floor((ui.height - win_height) / 2)
  local col = math.floor((ui.width - win_width) / 2)
  
  -- Set content
  if type(content) == "string" then
    local lines = {}
    for line in content:gmatch("([^\n]*)\n?") do
      table.insert(lines, line)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  elseif type(content) == "table" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  end
  
  -- Set window options
  local win_opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    border = "rounded",
    title = opts.title or "Preview",
    title_pos = "center",
    zindex = 200 -- Ensure it's on top
  }
  
  -- Create window
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  
  -- Set window-local options
  vim.api.nvim_win_set_option(win, 'wrap', true)
  vim.api.nvim_win_set_option(win, 'cursorline', true)
  vim.api.nvim_win_set_option(win, 'winhl', 'Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual')
  
  -- Set buffer-local options and mappings
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Add key mappings for closing
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
    noremap = true,
    silent = true,
    callback = function() vim.api.nvim_win_close(win, true) end,
  })
  
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '', {
    noremap = true,
    silent = true,
    callback = function() vim.api.nvim_win_close(win, true) end,
  })
  
  -- Make the window look nicer with some syntax highlighting
  if type(content) == "string" then
    local ns_id = vim.api.nvim_create_namespace("scaffolder_float")
    
    local lines = vim.split(content, "\n")
    for i, line in ipairs(lines) do
      -- Highlight file paths
      if line:match("^%s*•%s+") then
        vim.api.nvim_buf_add_highlight(buf, ns_id, "String", i-1, 0, -1)
      end
      
      -- Highlight titles
      if line:match("^Files to be created") then
        vim.api.nvim_buf_add_highlight(buf, ns_id, "Title", i-1, 0, -1)
      end
    end
  end
  
  -- Add a footer with instructions if not already present
  if type(content) == "string" and not content:match("Press 'y' to confirm") and not opts.no_footer then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    
    -- Add a separator
    table.insert(lines, "")
    table.insert(lines, string.rep("─", win_width - 2))
    
    -- Add instructions
    table.insert(lines, "")
    table.insert(lines, " Press 'y' to confirm or 'n'/Esc to cancel")
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    
    -- Highlight the footer
    local ns_id = vim.api.nvim_create_namespace("scaffolder_float")
    vim.api.nvim_buf_add_highlight(buf, ns_id, "Comment", #lines-1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, ns_id, "NonText", #lines-3, 0, -1)
  end
  
  return win, buf
end

-- Function to display preview in a large floating window
local function display_file_preview(preview, callback)
  local win, buf = create_floating_window(preview, {
    width = 100,  -- Wider window for longer paths
    height = 30,  -- Taller window to show more files
    title = "🗂️  File Creation Preview"
  })
  
  -- Add key mappings for Yes/No
  vim.api.nvim_buf_set_keymap(buf, 'n', 'y', '', {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
      callback(true)
    end,
  })
  
  vim.api.nvim_buf_set_keymap(buf, 'n', 'n', '', {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
      callback(false)
    end,
  })
  
  -- Apply additional highlighting for improved readability
  local ns_id = vim.api.nvim_create_namespace("scaffolder_preview")
  local lines = vim.split(preview, "\n")
  
  for i, line in ipairs(lines) do
    -- Highlight the header
    if i == 1 and line:match("^Files to be created") then
      vim.api.nvim_buf_add_highlight(buf, ns_id, "Title", i-1, 0, -1)
    end
    
    -- Highlight directory location
    if i == 2 and line:match("^in ") then
      vim.api.nvim_buf_add_highlight(buf, ns_id, "Special", i-1, 0, -1)
    end
    
    -- Highlight file paths 
    if line:match("^%s*•%s+") then
      vim.api.nvim_buf_add_highlight(buf, ns_id, "String", i-1, 0, -1)
    end
  end
end

-- Check for preferred picker
local function get_picker(opts)
  opts = opts or {}
  local picker = opts.picker or "auto"
  
  if picker == "auto" then
    -- Try fzf-lua first
    local has_fzf, _ = pcall(require, "fzf-lua")
    if has_fzf then
      return "fzf"
    end
    
    -- Try telescope next
    local has_telescope, _ = pcall(require, "telescope")
    if has_telescope then
      return "telescope"
    end
    
    -- Fallback to built-in vim.ui.select
    return "builtin"
  elseif picker == "snacks" then
    -- For now, just fallback to built-in as snacks integration is unstable
    vim.notify("Snacks integration is currently not working properly. Falling back to built-in picker.", vim.log.levels.WARN)
    return "builtin"
  else
    return picker
  end
end

-- Show snippets using telescope with improved UI
local function show_snippets_telescope(snippets, callback)
  local actions = require("telescope.actions")
  local actions_state = require("telescope.actions.state")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local previewers = require("telescope.previewers")
  
  -- Get icons if possible
  local icons = {
    plugin = "󰏗", -- Icon for plugin snippets
    user = "󰪩"    -- Icon for user snippets
  }
  
  -- Create formatted snippet entries
  local formatted_snippets = {}
  for _, snippet in ipairs(snippets) do
    table.insert(formatted_snippets, {
      display = format_snippet_entry(snippet),
      value = snippet,
      source = snippet.source,
      name = snippet.name,
      description = snippet.description or "",
      path = snippet.path
    })
  end
  
  -- Create entry maker with icons
  local entry_maker = function(entry)
    local icon = entry.source == "plugin" and icons.plugin or icons.user
    local display_name = entry.name
    local display_desc = entry.description ~= "" and (" - " .. entry.description) or ""
    
    return {
      value = entry.value,
      display = function()
        return icon .. " " .. display_name .. display_desc
      end,
      ordinal = entry.display,
      path = entry.path
    }
  end
  
  -- Create a simple previewer that shows snippet metadata
  local snippet_previewer = previewers.new_buffer_previewer({
    title = "Snippet Info",
    define_preview = function(self, entry, status)
      local snippet = entry.value
      local lines = {
        "Name: " .. snippet.name,
        "Source: " .. snippet.source
      }
      
      if snippet.description and snippet.description ~= "" then
        table.insert(lines, "")
        table.insert(lines, "Description: " .. snippet.description)
      end
      
      -- Add any additional metadata
      table.insert(lines, "")
      table.insert(lines, "Path: " .. snippet.path)
      
      -- Try to read and display the snippet content if possible
      local file = io.open(snippet.path, "r")
      if file then
        local content = file:read("*all")
        file:close()
        
        local ok, snippet_data = pcall(vim.json.decode, content)
        if ok and snippet_data then
          table.insert(lines, "")
          table.insert(lines, "Files that will be created:")
          
          for _, file_entry in ipairs(snippet_data.files or {}) do
            table.insert(lines, "  • " .. file_entry.path)
          end
        end
      end
      
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      
      -- Apply some basic syntax highlighting
      local ns_id = vim.api.nvim_create_namespace("scaffolder_preview")
      for i, line in ipairs(lines) do
        if line:match("^Name:") or line:match("^Source:") or line:match("^Description:") or line:match("^Path:") then
          vim.api.nvim_buf_add_highlight(self.state.bufnr, ns_id, "Title", i-1, 0, line:find(":")+1)
        end
        if line:match("^Files that will be created:") then
          vim.api.nvim_buf_add_highlight(self.state.bufnr, ns_id, "Special", i-1, 0, -1)
        end
        if line:match("^  •") then
          vim.api.nvim_buf_add_highlight(self.state.bufnr, ns_id, "String", i-1, 0, -1)
        end
      end
    end
  })
  
  -- Create the picker
  pickers.new({}, {
    prompt_title = "Select Snippet Template",
    finder = finders.new_table({
      results = formatted_snippets,
      entry_maker = entry_maker,
    }),
    previewer = snippet_previewer,
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local selection = actions_state.get_selected_entry()
        actions.close(prompt_bufnr)
        callback(selection.value)
      end)
      return true
    end,
  }):find()
end

-- Basic UI with separate floating windows
local function show_snippets_fzf(snippets, callback)
  local fzf = require("fzf-lua")
  
  -- Icons for different snippet sources
  local icons = {
    plugin = "󰏗", -- plugin icon
    user = "󰪩"    -- user icon
  }
  
  -- Generate formatted entries with icons
  local snippet_entries = {}
  local snippet_map = {}
  
  for _, snippet in ipairs(snippets) do
    local icon = snippet.source == "plugin" and icons.plugin or icons.user
    local desc = snippet.description and snippet.description ~= "" and (" - " .. snippet.description) or ""
    local display = icon .. " " .. snippet.name .. desc
    
    table.insert(snippet_entries, display)
    snippet_map[display] = snippet
  end
  
  -- State variables
  local current_root_dir = vim.fn.getcwd()
  local current_name = ""
  local current_snippet = nil
  local current_snippet_data = nil
  
  -- Window dimensions
  local ui = vim.api.nvim_list_uis()[1]
  local total_width = math.floor(ui.width * 0.9)
  local total_height = math.floor(ui.height * 0.8)
  local row = math.floor((ui.height - total_height) / 2)
  local col = math.floor((ui.width - total_width) / 2)
  
  -- Split dimensions
  local left_width = math.floor(total_width * 0.4)
  local right_width = total_width - left_width - 2 -- Account for separator
  
  -- Create buffers
  local preview_buf = vim.api.nvim_create_buf(false, true)
  local input_buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(preview_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(input_buf, 'bufhidden', 'wipe')
  
  -- Initialize input buffer
  vim.api.nvim_buf_set_option(input_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {"example"})
  
  -- Create the preview window (right side)
  local preview_win = vim.api.nvim_open_win(preview_buf, true, {
    relative = "editor",
    width = right_width,
    height = total_height - 4, -- Reserve space for input
    row = row + 4, -- Position below input
    col = col + left_width + 2, -- Position to the right of the FZF window
    style = "minimal",
    border = "rounded",
    title = "Preview",
    title_pos = "center"
  })
  
  -- Create input window (top right)
  local input_win = vim.api.nvim_open_win(input_buf, true, {
    relative = "editor",
    width = right_width,
    height = 1, 
    row = row + 1, -- Position at the top
    col = col + left_width + 2, -- Position to the right of the FZF window
    style = "minimal",
    border = "rounded",
    title = "Name",
    title_pos = "center"
  })
  
  -- Function to update preview
  local function update_preview()
    if not preview_buf or not vim.api.nvim_buf_is_valid(preview_buf) then 
      return 
    end
    
    local dir_text = current_root_dir and ("in " .. current_root_dir) or "in current directory"
    
    -- Variables with name transformations
    local name_to_show = current_name ~= "" and current_name or "example"
    
    -- Check for folder case preference in the snippet data
    local folder_case = "original"
    local folder_name = name_to_show
    
    if current_snippet_data and current_snippet_data.folder_case then
      folder_case = current_snippet_data.folder_case
      
      -- Format folder name according to preference
      if folder_case == "snake" then
        folder_name = to_snake_case(name_to_show)
      elseif folder_case == "kebab" then
        folder_name = to_kebab_case(name_to_show)
      elseif folder_case == "camel" then
        folder_name = to_camel_case(name_to_show)
      elseif folder_case == "pascal" then
        folder_name = to_pascal_case(name_to_show)
      elseif folder_case == "upper" then
        folder_name = to_upper_case(name_to_show)
      elseif folder_case == "lower" then
        folder_name = string.lower(name_to_show)
      end
    end
    
    local variables = {
      name = name_to_show,
      folder_name = folder_name,
      Name = to_pascal_case(name_to_show),
      name_snake = to_snake_case(name_to_show),
      name_kebab = to_kebab_case(name_to_show),
      name_camel = to_camel_case(name_to_show),
      NAME = to_upper_case(name_to_show)
    }
    
    -- Build preview content
    local lines = {"Files to be created " .. dir_text .. ":", ""}
    
    -- Add files first
    if current_snippet_data and current_snippet_data.files then
      table.insert(lines, "Files:")
      
      for _, file_entry in ipairs(current_snippet_data.files) do
        -- Use the folder_name variable directly in file paths
        local file_path = replace_variables(file_entry.path, variables)
        -- Don't show absolute paths in preview, keep it relative
        table.insert(lines, "  • " .. file_path)
      end
    else
      table.insert(lines, "Files:")
      table.insert(lines, "  • Select a template from the left panel")
    end
    
    -- Add name transformations below the files
    table.insert(lines, "")
    table.insert(lines, "Name transformations:")
    table.insert(lines, "  • PascalCase: " .. variables.Name)
    table.insert(lines, "  • snake_case: " .. variables.name_snake)
    table.insert(lines, "  • kebab-case: " .. variables.name_kebab)
    table.insert(lines, "  • camelCase: " .. variables.name_camel)
    table.insert(lines, "  • UPPER_CASE: " .. variables.NAME)
    table.insert(lines, "")
    
    -- Add footer
    table.insert(lines, "")
    table.insert(lines, "Press Enter to confirm, Esc to cancel")
    
    -- Update the buffer
    vim.api.nvim_buf_set_option(preview_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(preview_buf, 'modifiable', false)
    
    -- Apply highlighting
    local ns_id = vim.api.nvim_create_namespace("scaffolder_preview")
    vim.api.nvim_buf_clear_namespace(preview_buf, ns_id, 0, -1)
    
    for i, line in ipairs(lines) do
      -- Headers
      if i == 1 or line == "Name transformations:" or line == "Files:" then
        vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "Title", i-1, 0, -1)
      end
      
      -- File paths
      if line:match("^%s*•%s+") and not line:match("Original:") and not line:match("PascalCase:") and
         not line:match("snake_case:") and not line:match("kebab%-case:") and 
         not line:match("camelCase:") and not line:match("UPPER_CASE:") then
        vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "String", i-1, 0, -1)
      end
      
      -- Transformations
      if line:match("Original:") or line:match("PascalCase:") or line:match("snake_case:") or
         line:match("kebab%-case:") or line:match("camelCase:") or line:match("UPPER_CASE:") then
        local label_end = line:find(":")
        if label_end then
          vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "Identifier", i-1, 0, label_end)
          vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "Special", i-1, label_end+2, -1)
        end
      end
      
      -- Footer
      if i == #lines then
        vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "Comment", i-1, 0, -1)
      end
    end
  end
  
  -- FZF sink function that runs when a template is selected
  local function on_snippet_selected(selected)
    if not selected or #selected == 0 then return end
    
    local selected_snippet = snippet_map[selected[1]]
    if not selected_snippet then return end
    
    current_snippet = selected_snippet
    
    -- Read snippet data
    local file = io.open(selected_snippet.path, "r")
    if file then
      local content = file:read("*all")
      file:close()
      
      local ok, data = pcall(vim.json.decode, content)
      if ok and data then
        current_snippet_data = data
        
        -- Focus the input field and clear it
        vim.api.nvim_set_current_win(input_win)
        vim.api.nvim_buf_set_option(input_buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {""})
        
        -- Force insert mode with a slight delay to ensure it works
        vim.defer_fn(function()
          vim.cmd("startinsert!")
        end, 10)
        
        -- Update preview
        update_preview()
      end
    end
  end
  
  -- Set up text change watchers for input field
  local augroup = vim.api.nvim_create_augroup("ScaffolderNameInput", { clear = true })
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "InsertEnter", "InsertLeave"}, {
    group = augroup,
    buffer = input_buf,
    callback = function()
      current_name = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)[1] or ""
      update_preview()
    end,
  })
  
  -- Ensure we automatically enter insert mode when the input window gets focus 
  vim.api.nvim_create_autocmd("WinEnter", {
    buffer = input_buf,
    callback = function()
      vim.defer_fn(function()
        if vim.api.nvim_get_current_buf() == input_buf then
          vim.cmd("startinsert!")
        end
      end, 0)
    end
  })
  
  -- Add Enter key binding for input field to execute the action directly
  vim.api.nvim_buf_set_keymap(input_buf, 'i', '<CR>', '', {
    noremap = true, 
    silent = true,
    callback = function()
      if current_snippet and current_name and current_name ~= "" then
        -- First exit insert mode to return user to normal mode
        vim.cmd("stopinsert")
        
        -- Close windows safely with pcall to avoid errors
        pcall(function()
          if input_win and vim.api.nvim_win_is_valid(input_win) then
            vim.api.nvim_win_close(input_win, true)
          end
        end)
        
        pcall(function()
          if preview_win and vim.api.nvim_win_is_valid(preview_win) then
            vim.api.nvim_win_close(preview_win, true)
          end
        end)
        
        -- Create from snippet directly
        if current_root_dir then
          create_from_snippet(current_snippet.path, current_name, current_root_dir)
        else
          -- If no root directory, get current directory
          local cwd = vim.fn.getcwd()
          create_from_snippet(current_snippet.path, current_name, cwd)
        end
        
        -- Ensure user is returned to normal mode after creation
        vim.schedule(function()
          vim.cmd("stopinsert")
        end)
      end
    end,
  })
  
  -- Add Escape and q keymaps to close windows
  for _, buf in ipairs({input_buf, preview_buf}) do
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
      noremap = true,
      silent = true,
      callback = function()
        -- Safe window closing
        pcall(function()
          if input_win and vim.api.nvim_win_is_valid(input_win) then
            vim.api.nvim_win_close(input_win, true)
          end
        end)
        
        pcall(function()
          if preview_win and vim.api.nvim_win_is_valid(preview_win) then
            vim.api.nvim_win_close(preview_win, true)
          end
        end)
      end,
    })
    
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '', {
      noremap = true,
      silent = true,
      callback = function()
        -- Safe window closing
        pcall(function()
          if input_win and vim.api.nvim_win_is_valid(input_win) then
            vim.api.nvim_win_close(input_win, true)
          end
        end)
        
        pcall(function()
          if preview_win and vim.api.nvim_win_is_valid(preview_win) then
            vim.api.nvim_win_close(preview_win, true)
          end
        end)
      end,
    })
  end
  
  -- Initialize preview
  update_preview()
  
  -- Launch FZF in a floating window on the left side
  vim.defer_fn(function() 
    -- First set up the safety closure mechanism
    local windows_to_close = {}
    if input_win and vim.api.nvim_win_is_valid(input_win) then
      table.insert(windows_to_close, input_win)
    end
    if preview_win and vim.api.nvim_win_is_valid(preview_win) then
      table.insert(windows_to_close, preview_win)
    end
    
    -- Create a safe close function
    local function safe_close()
      -- Close the windows safely
      for _, win in ipairs(windows_to_close) do
        pcall(function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end)
      end
    end
    
    -- Create a safe complete function
    local function safe_complete(selected)
      if current_snippet and current_name and current_name ~= "" then
        safe_close()
        callback(current_snippet, current_name)
      end
    end
    
    -- Use a custom actions table with fzf.fzf_exec
    local fzf_job = fzf.fzf_exec(snippet_entries, {
      prompt = "Template > ",
      winopts = {
        relative = "editor",
        width = left_width,
        height = total_height,
        row = row,
        col = col,
        border = "rounded",
        title = "Templates",
        title_pos = "center",
        preview = { hidden = 'hidden' }
      },
      fzf_opts = {
        ['--layout'] = 'reverse',
        ['--info'] = 'inline',
        ['--pointer'] = '➜',
        ['--marker'] = '✓',
        ['--bind'] = 'change:first'
      },
      actions = {
        ["default"] = function(selected)
          -- When Enter is pressed
          if selected and #selected > 0 then
            on_snippet_selected(selected)
            
            -- Focus the input field and ensure we enter insert mode
            pcall(function()
              if input_win and vim.api.nvim_win_is_valid(input_win) then
                vim.api.nvim_set_current_win(input_win)
                
                -- First clear the field
                vim.api.nvim_buf_set_option(input_buf, 'modifiable', true)
                vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {""})
                
                -- Use defer_fn for more reliable insert mode
                vim.defer_fn(function()
                  if vim.api.nvim_win_is_valid(input_win) then
                    vim.cmd("startinsert!")
                  end
                end, 10)
              end
            end)
          end
          
          -- Return -1 to keep FZF open
          return -1
        end,
        
        ["ctrl-y"] = function(selected)
          -- When Ctrl+Y is pressed, execute the action directly
          if current_snippet and current_name and current_name ~= "" then
            -- Exit insert mode if we're in it
            vim.cmd("stopinsert")
            
            -- Close windows
            safe_close()
            
            -- Create from snippet directly
            if current_root_dir then
              create_from_snippet(current_snippet.path, current_name, current_root_dir)
            else
              -- If no root directory, get current directory
              local cwd = vim.fn.getcwd()
              create_from_snippet(current_snippet.path, current_name, cwd)
            end
            
            -- Ensure we're in normal mode after everything
            vim.schedule(function()
              vim.cmd("stopinsert")
            end)
          end
        end
      }
    })
    
    -- Add a global autocommand for cleanup
    local cleanup_id = vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        pcall(function()
          if fzf_job then
            vim.fn.jobstop(fzf_job)
          end
        end)
      end,
      once = true,
    })
    
    -- Set up a cleanup when windows are closed
    for _, win in ipairs(windows_to_close) do
      vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        callback = function()
          pcall(function()
            if fzf_job then
              vim.fn.jobstop(fzf_job)
            end
          end)
          vim.api.nvim_del_autocmd(cleanup_id)
        end,
        once = true,
      })
    end
  end, 10)
end

function M.select_snippet(opts)
  opts = opts or {}
  
  local snippets = get_snippets(opts)
  if #snippets == 0 then
    vim.notify("No snippets found", vim.log.levels.WARN)
    return
  end
  
  -- Get current directory from mini.files if it's active
  local root_dir = opts.root_dir
  if not root_dir then
    if is_mini_files_open() then
      root_dir = get_mini_files_current_dir()
    end
  end
  
  -- Determine which picker to use
  local picker_type = get_picker(opts)
  
  -- Handler for when a snippet is selected and a name is entered
  local function handle_snippet_name_selection(selected_snippet, name)
    if not selected_snippet or not name or name == "" then return end
    
    -- If we don't have a root directory, prompt for one
    if not root_dir then
      prompt_for_directory(function(directory)
        -- Generate preview and ask for confirmation
        local preview = generate_file_preview(selected_snippet.path, name, directory)
        
        display_file_preview(preview, function(confirmed)
          if confirmed then
            create_from_snippet(selected_snippet.path, name, directory, opts)
          end
        end)
      end)
    else
      -- We already have a root directory (from mini.files or options)
      -- Generate preview and ask for confirmation
      local preview = generate_file_preview(selected_snippet.path, name, root_dir)
      
      display_file_preview(preview, function(confirmed)
        if confirmed then
          create_from_snippet(selected_snippet.path, name, root_dir, opts)
        end
      end)
    end
  end
  
  -- Show snippets using the appropriate picker
  if picker_type == "fzf" then
    -- Use our new split UI with FZF
    show_snippets_fzf(snippets, function(selected_snippet, name)
      if not selected_snippet or not name or name == "" then 
        return 
      end
      
      -- If we don't have a root directory, prompt for one
      if not root_dir then
        prompt_for_directory(function(directory)
          -- Create directly without confirmation
          create_from_snippet(selected_snippet.path, name, directory, opts)
        end)
      else
        -- We already have a root directory, create directly
        create_from_snippet(selected_snippet.path, name, root_dir, opts)
      end
    end)
  elseif picker_type == "telescope" then
    -- Currently using the old flow for Telescope, should be updated in the future
    show_snippets_telescope(snippets, function(selected_snippet)
      if not selected_snippet then return end
      
      -- If we don't have a root directory, prompt for one
      if not root_dir then
        prompt_for_directory(function(directory)
          -- Prompt for the name
          vim.ui.input({
            prompt = "Enter name: ",
            default = "",
            highlight = function()
              -- Put user in insert mode after the prompt appears
              vim.schedule(function() vim.cmd("startinsert") end)
            end,
          }, function(input)
            if input and input ~= "" then
              -- Create directly without confirmation
              create_from_snippet(selected_snippet.path, input, directory, opts)
            end
          end)
        end)
      else
        -- We already have a root directory
        vim.ui.input({
          prompt = "Enter name: ",
          default = "",
          completion = "file",
          highlight = function()
            -- Put user in insert mode after the prompt appears
            vim.schedule(function() vim.cmd("startinsert") end)
          end,
        }, function(input)
          if input and input ~= "" then
            -- Create directly without confirmation
            create_from_snippet(selected_snippet.path, input, root_dir, opts)
          end
        end)
      end
    end)
  else
    -- Currently using the old flow for built-in, should be updated in the future
    show_snippets_builtin(snippets, function(selected_snippet)
      if not selected_snippet then return end
      
      -- If we don't have a root directory, prompt for one
      if not root_dir then
        prompt_for_directory(function(directory)
          -- Prompt for the name
          vim.ui.input({
            prompt = "Enter name: ",
            default = "",
            highlight = function()
              -- Put user in insert mode after the prompt appears
              vim.schedule(function() vim.cmd("startinsert") end)
            end,
          }, function(input)
            if input and input ~= "" then
              handle_snippet_name_selection(selected_snippet, input)
            end
          end)
        end)
      else
        -- We already have a root directory
        vim.ui.input({
          prompt = "Enter name: ",
          default = "",
          completion = "file",
          highlight = function()
            -- Put user in insert mode after the prompt appears
            vim.schedule(function() vim.cmd("startinsert") end)
          end,
        }, function(input)
          if input and input ~= "" then
            handle_snippet_name_selection(selected_snippet, input)
          end
        end)
      end
    end)
  end
end

-- Show snippets using vim.ui.select with better formatting
local function show_snippets_builtin(snippets, callback)
  local formatted_snippets = {}
  local snippet_map = {}
  
  -- Icons for different snippet sources
  local icons = {
    plugin = "󰏗", -- plugin icon
    user = "󰪩"    -- user icon
  }
  
  for _, snippet in ipairs(snippets) do
    local icon = snippet.source == "plugin" and icons.plugin or icons.user
    local display = string.format("%s %s", icon, snippet.name)
    if snippet.description and snippet.description ~= "" then
      display = display .. " - " .. snippet.description
    end
    
    table.insert(formatted_snippets, display)
    snippet_map[display] = snippet
  end
  
  -- Preview function that would show metadata about the snippet
  local function show_preview(snippet)
    if not snippet then return end
    
    local preview_win, preview_buf = create_floating_window("", {
      width = 60,
      height = 15,
      title = "Snippet Preview"
    })
    
    local lines = {
      "Name: " .. snippet.name,
      "Source: " .. snippet.source
    }
    
    if snippet.description and snippet.description ~= "" then
      table.insert(lines, "")
      table.insert(lines, "Description: " .. snippet.description)
    end
    
    -- Try to read the snippet and show file structure
    local file = io.open(snippet.path, "r")
    if file then
      local content = file:read("*all")
      file:close()
      
      local ok, snippet_data = pcall(vim.json.decode, content)
      if ok and snippet_data then
        table.insert(lines, "")
        table.insert(lines, "Files that will be created:")
        
        for _, file_entry in ipairs(snippet_data.files or {}) do
          table.insert(lines, "  • " .. file_entry.path)
        end
      end
    end
    
    vim.api.nvim_buf_set_option(preview_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(preview_buf, 'modifiable', false)
    
    -- Apply some syntax highlighting
    local ns_id = vim.api.nvim_create_namespace("scaffolder_preview")
    for i, line in ipairs(lines) do
      if line:match("^Name:") or line:match("^Source:") or line:match("^Description:") then
        vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "Title", i-1, 0, line:find(":")+1)
      end
      if line:match("^Files that will be created:") then
        vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "Special", i-1, 0, -1)
      end
      if line:match("^  •") then
        vim.api.nvim_buf_add_highlight(preview_buf, ns_id, "String", i-1, 0, -1)
      end
    end
    
    return preview_win, preview_buf
  end
  
  -- Handle preview window
  local preview_win, preview_buf
  
  vim.ui.select(formatted_snippets, {
    prompt = "Select snippet template:",
    format_item = function(item)
      return item
    end,
    kind = "scaffolder.snippets"
  }, function(choice)
    -- Close the preview window if it exists
    if preview_win and vim.api.nvim_win_is_valid(preview_win) then
      vim.api.nvim_win_close(preview_win, true)
    end
    
    if choice then
      callback(snippet_map[choice])
    end
  end)
  
  -- Try to show preview for first item
  if #formatted_snippets > 0 then
    local first_choice = formatted_snippets[1]
    preview_win, preview_buf = show_preview(snippet_map[first_choice])
  end
end

-- Show snippets using snacks with enhanced UI
local function show_snippets_snacks(snippets, callback)
  local snacks = require("snacks")
  
  -- Create rich entry items with metadata
  local snippet_entries = {}
  for _, snippet in ipairs(snippets) do
    table.insert(snippet_entries, {
      display = snippet.name,
      description = snippet.description or "",
      value = snippet, -- Store the full snippet object for callback
      icon = snippet.source == "plugin" and "󰏗" or "󰪩", -- Unicode icons for plugin/user snippets
      badge = snippet.source,
      source = snippet.source,
      path = snippet.path
    })
  end
  
  -- Define a custom preview function
  local preview_function = function(_, item)
    if not item or not item.value then return "" end
    
    local snippet = item.value
    local file_path = snippet.path
    
    -- Try to read snippet content to show files that will be created
    local file_preview = {}
    table.insert(file_preview, "# " .. snippet.name)
    table.insert(file_preview, "")
    
    if snippet.description and snippet.description ~= "" then
      table.insert(file_preview, snippet.description)
      table.insert(file_preview, "")
    end
    
    table.insert(file_preview, "**Source**: " .. snippet.source)
    table.insert(file_preview, "**Path**: " .. snippet.path)
    table.insert(file_preview, "")
    
    -- Try to parse the JSON file to get files
    local file = io.open(file_path, "r")
    if file then
      local content = file:read("*all")
      file:close()
      
      local ok, data = pcall(vim.json.decode, content)
      if ok and data and data.files then
        table.insert(file_preview, "## Files that will be created:")
        table.insert(file_preview, "")
        
        for _, file_entry in ipairs(data.files) do
          table.insert(file_preview, "- " .. file_entry.path)
        end
      end
    end
    
    return table.concat(file_preview, "\n")
  end
  
  -- Use the picker API directly for advanced features
  snacks.pick({
    prompt = "Select snippet template",
    items = snippet_entries,
    preview = {
      fn = preview_function,
      side = "right", -- Show preview on the right side
      width = 0.5,    -- Take up half the screen width
    },
    format_item = function(item)
      local desc = item.description ~= "" and (" - " .. item.description) or ""
      return string.format("%s  %s%s", item.icon, item.display, desc)
    end,
    actions = {
      ["default"] = function(picker, items)
        if #items > 0 then
          picker:close()
          callback(items[1].value)
        end
      end,
      ["<C-y>"] = function(picker, items)
        if #items > 0 then
          picker:close()
          callback(items[1].value)
        end
      end,
    },
    opts = {
      label = "Scaffolder Templates",
      title = "🗂️  Snippet Templates",
      badge = {
        plugin = { hl = "Special" },
        user = { hl = "Type" }
      }
    }
  })
end

-- Function to select a snippet using the appropriate picker
function M.select_snippet(opts)
  opts = opts or {}
  
  local snippets = get_snippets(opts)
  if #snippets == 0 then
    vim.notify("No snippets found", vim.log.levels.WARN)
    return
  end
  
  -- Get current directory from mini.files if it's active
  local root_dir = opts.root_dir
  if not root_dir then
    if is_mini_files_open() then
      root_dir = get_mini_files_current_dir()
    end
  end
  
  -- Determine which picker to use
  local picker_type = get_picker(opts)
  
  -- Handler for when a snippet is selected and a name is entered
  local function handle_snippet_name_selection(selected_snippet, name)
    if not selected_snippet or not name or name == "" then return end
    
    -- If we don't have a root directory, prompt for one
    if not root_dir then
      prompt_for_directory(function(directory)
        -- Generate preview and ask for confirmation
        local preview = generate_file_preview(selected_snippet.path, name, directory)
        
        display_file_preview(preview, function(confirmed)
          if confirmed then
            create_from_snippet(selected_snippet.path, name, directory, opts)
          end
        end)
      end)
    else
      -- We already have a root directory (from mini.files or options)
      -- Generate preview and ask for confirmation
      local preview = generate_file_preview(selected_snippet.path, name, root_dir)
      
      display_file_preview(preview, function(confirmed)
        if confirmed then
          create_from_snippet(selected_snippet.path, name, root_dir, opts)
        end
      end)
    end
  end
  
  -- Show snippets using the appropriate picker
  if picker_type == "fzf" then
    -- Use our unified UI with FZF
    show_snippets_fzf(snippets, handle_snippet_name_selection)
  elseif picker_type == "telescope" then
    -- Currently using the old flow for Telescope, should be updated in the future
    show_snippets_telescope(snippets, function(selected_snippet)
      if not selected_snippet then return end
      
      -- If we don't have a root directory, prompt for one
      if not root_dir then
        prompt_for_directory(function(directory)
          -- Prompt for the name
          vim.ui.input({
            prompt = "Enter name: ",
            default = "",
            highlight = function()
              -- Put user in insert mode after the prompt appears
              vim.schedule(function() vim.cmd("startinsert") end)
            end,
          }, function(input)
            if input and input ~= "" then
              handle_snippet_name_selection(selected_snippet, input)
            end
          end)
        end)
      else
        -- We already have a root directory
        vim.ui.input({
          prompt = "Enter name: ",
          default = "",
          completion = "file",
          highlight = function()
            -- Put user in insert mode after the prompt appears
            vim.schedule(function() vim.cmd("startinsert") end)
          end,
        }, function(input)
          if input and input ~= "" then
            handle_snippet_name_selection(selected_snippet, input)
          end
        end)
      end
    end)
  else
    -- Currently using the old flow for built-in, should be updated in the future
    show_snippets_builtin(snippets, function(selected_snippet)
      if not selected_snippet then return end
      
      -- If we don't have a root directory, prompt for one
      if not root_dir then
        prompt_for_directory(function(directory)
          -- Prompt for the name
          vim.ui.input({
            prompt = "Enter name: ",
            default = "",
            highlight = function()
              -- Put user in insert mode after the prompt appears
              vim.schedule(function() vim.cmd("startinsert") end)
            end,
          }, function(input)
            if input and input ~= "" then
              handle_snippet_name_selection(selected_snippet, input)
            end
          end)
        end)
      else
        -- We already have a root directory
        vim.ui.input({
          prompt = "Enter name: ",
          default = "",
          completion = "file",
          highlight = function()
            -- Put user in insert mode after the prompt appears
            vim.schedule(function() vim.cmd("startinsert") end)
          end,
        }, function(input)
          if input and input ~= "" then
            handle_snippet_name_selection(selected_snippet, input)
          end
        end)
      end
    end)
  end
end

-- Empty placeholder function - notification removed
local function show_mini_files_welcome()
  -- Notification removed
end

-- Function to trigger snippet selection from mini.files
function M.mini_files_snippet(opts)
  opts = opts or {}
  
  if not is_mini_files_open() then
    vim.notify("No mini.files explorer detected. Please open mini.files first with :lua MiniFiles.open()", vim.log.levels.WARN)
    return
  end
  
  -- Get the current directory from mini.files
  local current_dir = get_mini_files_current_dir()
  
  local new_opts = vim.tbl_extend("force", opts, { root_dir = current_dir })
  M.select_snippet(new_opts)
end

-- Internal function to run case transformation tests
local function run_case_transformation_tests()
  test_case_transformations()
end

-- Create command to trigger the functionality
function M.setup(opts)
  opts = opts or {}
  
  -- Validate picker option
  if opts.picker and type(opts.picker) == "string" then
    -- Ensure picker is one of the supported types
    if not vim.tbl_contains({"auto", "telescope", "fzf", "builtin"}, opts.picker) then
      if opts.picker == "snacks" then
        vim.notify(
          "Snacks integration is currently disabled. Using 'auto' instead.",
          vim.log.levels.WARN
        )
      else
        vim.notify(
          "Invalid picker type: " .. opts.picker .. ". Using 'auto' instead.",
          vim.log.levels.WARN
        )
      end
      opts.picker = "auto"
    end
  end
  
  -- Create commands
  vim.api.nvim_create_user_command("MultiFileSnippet", function()
    local mini_files_dir = nil
    if is_mini_files_open() then
      -- If mini.files is open, use its current directory
      mini_files_dir = get_mini_files_current_dir()
    end
    
    local cmd_opts = {
      root_dir = mini_files_dir,
      picker = opts.picker or "auto"
    }
    
    M.select_snippet(cmd_opts)
  end, {})
  
  -- Create command specifically for mini.files integration
  vim.api.nvim_create_user_command("MiniFilesSnippet", function()
    M.mini_files_snippet({picker = opts.picker or "auto"})
  end, {})
  
  -- Create version command
  vim.api.nvim_create_user_command("ScaffolderVersion", function()
    M.show_version()
  end, {})
  
  -- Create test command (for development only)
  vim.api.nvim_create_user_command("ScaffolderTestCasing", function()
    run_case_transformation_tests()
  end, {})
  
  -- Set up integration with mini.files
  -- Set autocmd for mini.files windows
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "minifiles",
    callback = function(args)
      local buf = args.buf
      -- Map Ctrl-m to trigger snippet creation in mini.files
      vim.keymap.set("n", "<C-m>", function()
        M.mini_files_snippet({picker = opts.picker or "auto"})
      end, { buffer = buf, desc = "Create directory from snippet" })
      
      -- Show welcome message
      show_mini_files_welcome()
    end,
  })
  
  -- Alternative detection for mini.files - check for the window open event
  local mini_files_group = vim.api.nvim_create_augroup("ScaffolderMiniFiles", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    pattern = "MiniFilesWindowOpen",
    group = mini_files_group,
    callback = function(args)
      local win_id = args.data and args.data.win_id
      if win_id then
        local buf_id = vim.api.nvim_win_get_buf(win_id)
        vim.keymap.set("n", "<C-m>", function()
          M.mini_files_snippet({picker = opts.picker or "auto"})
        end, { buffer = buf_id, desc = "Create directory from snippet" })
        
        -- Show welcome message
        show_mini_files_welcome()
      end
    end,
  })
  
  -- Also listen for MiniFilesExplorerOpen event
  vim.api.nvim_create_autocmd("User", {
    pattern = "MiniFilesExplorerOpen",
    group = mini_files_group,
    callback = function()
      -- Show welcome message
      show_mini_files_welcome()
    end,
  })
  
end

-- Make internal functions available for testing
if vim.fn.exists("$TEST_ENV") == 1 then
  M._to_snake_case = to_snake_case
  M._to_kebab_case = to_kebab_case
  M._to_camel_case = to_camel_case
  M._to_pascal_case = to_pascal_case
  M._to_upper_case = to_upper_case
  M._run_case_transformation_tests = run_case_transformation_tests
end

return M