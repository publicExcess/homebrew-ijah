# homebrew-ijah

Homebrew tap for [Ijah](https://github.com/publicExcess/ijah), a raw-Metal inference engine for Qwen3.8-Flash-Next
and Swift-1.5. It needs an Apple M5 Mac on macOS 27 with Xcode and the Metal toolchain
(`xcodebuild -downloadComponent MetalToolchain`).

```sh
brew install publicExcess/ijah/ijah          # builds the engine, the server's Python env and the `ijah` command
ijah download base drafter ngram             # ~83 + 1.2 + 102 GB into ~/.cache/ijah (the T6 pack is the preferred one)
ijah serve start                             # or: brew services start ijah
```

`ijah doctor` checks the machine, the packs, the key and the port. `ijah --help` lists the other commands.
