# V0.3 release gates

## Complete in source/automated checks

- [x] Godot source, room-server source, Windows/Android native export configuration included
- [x] 11 original glTF `.glb` meshes created, parsed back and verified
- [x] Required GDScript load/preload paths resolve in the package
- [x] Fast-travel zone list matches server-side approved coordinates
- [x] Private-room WebSocket smoke tests cover join, live movement, shared coins, eight-player cap, invalid rooms, leaving and fast travel
- [x] ZIP integrity and file structure check

## Pending actual build/runtime verification

- [ ] Import v0.3 project into **Godot 4.5.2**, confirm no GDScript parser errors
- [ ] Fix any GLB importer issues or GL Compatibility rendering issues seen in engine
- [ ] Run `.github/workflows/android-debug-apk.yml`, confirm APK and signature generated
- [ ] Install and open on Android 13, 15 and 16 compatible ARM64 devices
- [ ] Verify no overexposure/whiteouts, readable UI in 16:9 and tall aspect ratios
- [ ] Measure actual frame rate, device heat, battery and load time
- [ ] Deploy free Cloudflare server, set `SERVER_URL`, test two real devices in same world
- [ ] Validate car, race, slide, pet, coins, local collisions and fast travel both offline and online
- [ ] Conduct child privacy, moderation, access-control, security and jurisdiction-specific compliance review before public distribution

**Do not call this release production-ready until all necessary gates are closed.**
