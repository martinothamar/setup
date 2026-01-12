## VSCode setup

Once it is installed

```sh
# VSCode extensions (in WSL, on Windows host, or both)
code --install-extension ms-vscode-remote.remote-wsl
code --install-extension ms-vscode-remote.remote-ssh

# Utilities
code --install-extension EditorConfig.EditorConfig
code --install-extension eamodio.gitlens
code --install-extension medo64.render-crlf
code --install-extension tomoki1207.pdf
code --install-extension GitHub.vscode-github-actions

# Clients
code --install-extension humao.rest-client
code --install-extension bruno-api-client.bruno

# Diagramming
code --install-extension hediet.vscode-drawio
code --install-extension pomdtr.excalidraw-editor

# Languages
code --install-extension redhat.vscode-yaml
code --install-extension redhat.vscode-xml
code --install-extension ms-dotnettools.csdevkit
code --install-extension csharpier.csharpier-vscode
code --install-extension golang.Go
code --install-extension rust-lang.rust-analyzer
code --install-extension ziglang.vscode-zig
code --install-extension jnoortheen.nix-ide
```

User settings
```json
{
    "extensions.ignoreRecommendations": true,
    "editor.renderWhitespace": "all",
    "editor.minimap.enabled": false,
    "[csharp]": {
        "editor.defaultFormatter": "csharpier.csharpier-vscode"
    },
    "[xml]": {
        "editor.defaultFormatter": "csharpier.csharpier-vscode"
    },
    "remote.autoForwardPortsSource": "hybrid",
    "zig.zls.enabled": "on",
    "rust-analyzer.inlayHints.typeHints.enable": false,
    "dotnet.solution.autoOpen": "false"
}
```
