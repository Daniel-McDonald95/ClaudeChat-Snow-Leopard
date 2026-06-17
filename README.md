# ClaudeChat-Snow-Leopard (iChatAI)

A native macOS Snow Leopard (10.6.8) Cocoa AI chat client powered by the Anthropic Claude API.

Built and tested on a White MacBook (MacBook4,1) running 10.6.8.

## Features
- Native Cocoa app (Objective-C, manual retain/release, no ARC)
- iChat-style HTML chat bubbles via WebView
- Bundled curl-static binary for TLS 1.2 support on 10.6
- API key stored securely in macOS Keychain
- Setup window on first launch

## Requirements
- macOS 10.6 Snow Leopard
- Anthropic API key (get one at https://console.anthropic.com)

## Installation
Download iChatAI-1.0.pkg from Releases and run the installer.

## Building from Source
- Xcode 3.2.6
- Open iChatAI.xcodeproj and build

## Version History
- v1.0 - Initial release
