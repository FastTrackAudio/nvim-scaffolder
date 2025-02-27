# scaffolder.nvim

Neovim plugin that creates directories and files from JSON snippet templates.

## Features

- 📁 Create directory structures from templates
- ✨ FZF-powered snippet selection
- 🔄 Smart case transformations (camelCase, PascalCase, etc.)
- 📚 Built-in snippets included
- 🔌 Integration with mini.files

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'yourusername/scaffolder.nvim',
  requires = {
    'ibhagwan/fzf-lua',
    'echasnovski/mini.files', -- optional
  }
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'yourusername/scaffolder.nvim',
  dependencies = {
    'ibhagwan/fzf-lua',
    'echasnovski/mini.files', -- optional
  },
  config = function()
    require('scaffolder').setup({})
  end
}
```

## Usage

### Standalone Mode

1. Run the `:MultiFileSnippet` command in Neovim
2. Select a snippet from the FZF window
3. Enter a name when prompted
4. Files and directories will be created relative to your current directory

### Mini.files Integration

When using [mini.files](https://github.com/echasnovski/mini.files):

1. Open mini.files with your preferred method (e.g., `:lua MiniFiles.open()`)
2. Navigate to the directory where you want to create your new structure
3. Press `<C-m>` or run `:MiniFilesSnippet`
4. Select a snippet and enter a name
5. Files will be created relative to your current directory in mini.files

The plugin looks for snippets in two locations:
- User snippets: `~/.config/nvim/snippets/multi-file/`
- Built-in snippets: Included in the plugin (no setup required)

## Configuration

```lua
require('scaffolder').setup({
  snippet_dir = '~/my-snippets',  -- Optional custom path for user snippets
  show_version_on_startup = true, -- Show full version info at startup
})
```

## Snippet Format

```json
{
  "name": "Example Snippet",
  "description": "Creates a basic directory structure",
  "files": [
    {
      "path": "${name}/index.ts",
      "content": "export * from './${name:kebab}.service';\n"
    },
    {
      "path": "${name}/${name:kebab}.service.ts",
      "content": "console.log('This is the ${name:pascal} service');\n"
    },
    {
      "path": "${name}/__tests__/",
      "content": ""
    },
    {
      "path": "${name}/types/${name:kebab}.type.ts",
      "content": "export type ${name:pascal} = {\n  id: string;\n};\n"
    }
  ]
}
```

## Case Transformations

You can use format specifiers to apply case transformations to variables:

- `${name}` - As entered (e.g., "test")
- `${name:pascal}` - PascalCase (e.g., "TestName" from any input format)
- `${name:camel}` - camelCase (e.g., "testName" from any input format)
- `${name:snake}` - snake_case (e.g., "test_name" from any input format)
- `${name:kebab}` - kebab-case (e.g., "test-name" from any input format)
- `${name:upper}` - UPPER_CASE (e.g., "TEST_NAME" from any input format)

Case transformations handle any input format consistently. For example, all of these inputs:
`test-file`, `TESTFILE`, `Test_File`, `testFile`, `TestFile` will produce the same consistent output
in each format.

## Example

When running `:MultiFileSnippet` and selecting the "Multi-File Test" template, entering "user-profile" will create:

```
user-profile/
├── __tests__/
├── index.ts                 // exports from user-profile.service and user-profile.hooks
├── user-profile.hooks.ts    // Has exports like useUserProfile()
├── user-profile.service.ts  // Has exports like userProfileService
└── types/
    └── user-profile.type.ts // Has types like UserProfile
```

## Built-in Snippets

The plugin comes with several built-in snippets:

1. **Multi-File Test** - Basic TypeScript module structure with service, hooks, and types
2. **React Component** - React component with styles and tests
3. **NestJS Module** - Complete NestJS module with controller, service, DTOs and tests

## Commands

- `:MultiFileSnippet` - Open FZF to select a snippet template
- `:MiniFilesSnippet` - Same as above, but specifically for mini.files
- `:ScaffolderVersion` - Display the current plugin version

## License

MIT