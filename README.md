# Build

```
docker buildx build . --build-arg QDZ_PLATFORM=cyclonev -t quartus-multiarch
```

# Run

```
docker run -it -v $(pwd):/build quartus-multiarch "quartus_sh --flow compile projectname"
```