---
name: vscode-rescript-ext-migrator
description: Procedural guidance and idiomatic bindings for migrating VSCode extensions from TypeScript to ReScript v12. Use when porting extension.ts files or implementing new VSCode features in ReScript.
---
# VSCode ReScript Migration Guide

## 🔷 Core Philosophy
- **Minimize Dependencies**: Prefer lightweight external bindings over massive binding libraries.
- **Deno-First**: For LSP runners, leverage Deno's async capabilities via `%raw` or clean externals.
- **Type Safety**: Fully model VSCode's `ExtensionContext` and `Command` registration.

## 📝 Common Bindings

```rescript
module VsCode = {
  type extensionContext = {
    subscriptions: array<unit => unit>,
    asAbsolutePath: string => string,
  }

  module Window = {
    @module("vscode") @scope("window")
    external showInformationMessage: string => promise<unit> = "showInformationMessage"
    
    @module("vscode") @scope("window")
    external showErrorMessage: string => promise<unit> = "showErrorMessage"

    @module("vscode") @scope("window")
    external createTerminal: string => 'terminal = "createTerminal"
  }

  module Commands = {
    @module("vscode") @scope("commands")
    external registerCommand: (string, unit => promise<unit>) => unit = "registerCommand"
  }
}
```

## 🚀 Workflow: Porting extension.ts
1. **Model the State**: Define the `client` and `statusBar` types as options.
2. **Externalize Modules**: Map `path` and `vscode-languageclient` to ReScript externals.
3. **Translate Lifecycle**:
   - `activate` -> `let activate = (context: VsCode.extensionContext) => { ... }`
   - `deactivate` -> `let deactivate = () => { ... }`
4. **Handle Async**: Use ReScript v12's `async/await` for command handlers.
