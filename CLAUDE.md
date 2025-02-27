# Commands & Guidelines for scaffolder.nvim

## Commands
- **Format**: `stylua .` (format all Lua files)
- **Format check**: `stylua --check .` (check formatting without changing)
- **Test all**: `nvim --headless -c "PlenaryBustedDirectory test/ {minimal_init = 'test/minimal_init.lua'}"` 
- **Test single**: `nvim --headless -c "PlenaryBustedFile test/plugin_spec.lua"`
- **Build docs**: Generated automatically from README via panvimdoc in CI

## Code Style
- Use StyLua for formatting (configured in `.stylua.toml`)
- Declare functions with `local function name()` pattern
- Export via return table pattern: `return { func = func }`
- Use snake_case for variables and functions
- Prefer local variables over global
- Keep functions small and focused
- Use descriptive variable names
- Comments should explain "why" not "what"
- Follow Neovim plugin conventions for API design

## Project Structure
- `lua/scaffolder/init.lua`: Main plugin code
- `plugin/scaffolder.lua`: Plugin registration
- `test/plugin_spec.lua`: Tests (using Busted framework)
- `doc/scaffolder.txt`: Documentation (generated from README)