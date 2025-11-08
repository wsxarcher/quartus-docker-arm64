# Platform Support Matrix

| 🖥️ Platform       | 💾 Architecture | ✅ Status | ⚙️ Notes |
|-------------------|----------------|-----------|----------|
| 🍎 macOS          | x64            | ✅ Works  | 🐳 Docker VM |
| 🍎 macOS          | ARM64          | ✅ Works  | 🐳 Docker VM + 🧬 FEX |
| 🐧 Linux          | x64            | ✅ Works  | — |
| 🐧 Linux          | ARM64          | ✅ Works  | 🧬 FEX |
| 🪟 Windows        | x64            | ✅ Works  | 🐳 Docker VM |
| 🪟 Windows        | ARM64          | ✅ Works  | 🐳 Docker VM + 🧬 FEX |

# Build

```
docker buildx build . --build-arg QDZ_PLATFORM=cyclonev -t quartus-multiarch
```

# Run

```
docker run -it -v $(pwd):/build quartus-multiarch "quartus_sh --flow compile projectname"
```
