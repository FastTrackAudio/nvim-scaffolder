-- Test runner for case transformation functions
-- Run this with :luafile test/casing_tests.lua

-- Load the module
local scaffolder = require('scaffolder')

-- Define test cases
local test_cases = {
  "test-string",
  "test_string",
  "testString",
  "TestString",
  "TEST_STRING",
  "Test String",
  "test-camel-case",
  "test_snake_case",
  "TestPascalCase",
  "UPPER_CASE_NAME"
}

-- Execute tests
print("\n==========================================")
print("Running case transformation tests...")
print("==========================================\n")

for _, test_case in ipairs(test_cases) do
  print("Input: \"" .. test_case .. "\"")
  
  -- Run all case transformations
  local snake = scaffolder._to_snake_case(test_case)
  local kebab = scaffolder._to_kebab_case(test_case)
  local camel = scaffolder._to_camel_case(test_case)
  local pascal = scaffolder._to_pascal_case(test_case)
  local upper = scaffolder._to_upper_case(test_case)
  
  -- Print results
  print("  snake_case:  " .. snake)
  print("  kebab-case:  " .. kebab)
  print("  camelCase:   " .. camel)
  print("  PascalCase:  " .. pascal)
  print("  UPPER_CASE:  " .. upper)
  print("")
  
  -- Verify expected output format
  local snake_pattern = "^[a-z0-9_]+$"
  local kebab_pattern = "^[a-z0-9%-]+$"
  local camel_pattern = "^[a-z][a-zA-Z0-9]*$"
  local pascal_pattern = "^[A-Z][a-zA-Z0-9]*$"
  local upper_pattern = "^[A-Z0-9_]+$"
  
  local function check(value, pattern, name)
    if not string.match(value, pattern) then
      print("ERROR: " .. name .. " transformation failed for \"" .. test_case .. "\"")
      print("       Got: \"" .. value .. "\" which doesn't match expected pattern")
    end
  end
  
  check(snake, snake_pattern, "snake_case")
  check(kebab, kebab_pattern, "kebab-case")
  check(camel, camel_pattern, "camelCase")
  check(pascal, pascal_pattern, "PascalCase") 
  check(upper, upper_pattern, "UPPER_CASE")
end

print("==========================================")
print("Test complete!")
print("==========================================\n")

-- Test the format specifier feature
-- This simulates what happens in actual template substitution
local function test_substitution()
  print("\n==========================================")
  print("Testing variable substitution with formats...")
  print("==========================================\n")
  
  local M = {}
  
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
    end):sub(2)
    
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
  
  -- Test cases
  local test_inputs = {
    "test-name",
    "TestName",
    "test_name",
    "testName",
    "TEST_NAME"
  }
  
  for _, input in ipairs(test_inputs) do
    print("Template substitution with input: \"" .. input .. "\"")
    
    -- Create variables table like in the main code
    local variables = {
      name = input,
      Name = to_pascal_case(input),
      name_snake = to_snake_case(input),
      name_kebab = to_kebab_case(input),
      name_camel = to_camel_case(input),
      NAME = to_upper_case(input)
    }
    
    -- Test template strings
    local templates = {
      "Path: ${name}/index.ts",
      "Name: ${name:pascal}",
      "FileName: ${name:kebab}.service.ts",
      "Variable: ${name:camel}Service",
      "Constant: ${name:upper}_ID",
      "Legacy PascalCase: ${Name}",
      "Legacy snake_case: ${name_snake}",
      "Legacy UPPER_CASE: ${NAME}"
    }
    
    for _, template in ipairs(templates) do
      local result = replace_variables(template, variables)
      print("  " .. template .. " => " .. result)
    end
    
    print("")
  end
  
  print("==========================================")
  print("Substitution test complete!")
  print("==========================================\n")
end

test_substitution()