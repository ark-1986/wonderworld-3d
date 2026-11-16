# Gameplay and multiplayer verification checklist

This is an honest checklist to run when the project is opened in Godot and the server is deployed.

## Engine smoke test
- [ ] Godot 4.5.2 opens `godot/project.godot` without parser errors.
- [ ] Main menu is visible over a cheerful 3D island.
- [ ] "PRACTICE OFFLINE" starts the 3D scene; camera follows the player.
- [ ] WASD/arrows and touch joystick move the avatar; Space/JUMP jumps.
- [ ] Landing works on the island and raised platforms.
- [ ] Touching gems hides them and adds 10 points in offline mode.
- [ ] Gems reappear after about 24 seconds.
- [ ] HOME returns to menu and restarts cleanly.
- [ ] Music and gem effects play at a reasonable volume.

## Server smoke test
- [ ] `npm install` and `npm run deploy` succeed on free Cloudflare plan.
- [ ] `https://<worker>.workers.dev/health` returns `{ "ok": true, ... }`.
- [ ] Deployed server URL configured in `godot/scripts/network.gd` uses `wss://`.
- [ ] Two test Android phones can join the same eight-character room code.
- [ ] Both avatars appear in each other's world and move smoothly.
- [ ] A third player sees both avatars.
- [ ] Gem pickup updates the shared scoreboard for both players.
- [ ] Collected gems reappear about 24s later, while room is active.
- [ ] Leaving a room removes the avatar on the other device.
- [ ] Ninth player cannot join an eight-player room.
- [ ] Disconnecting Wi-Fi does not crash the game.
- [ ] Test on low-end Android hardware and mobile data; measure FPS/latency.

## Safety before wider distribution
- [ ] Restrict testing to family/friends; never share public room codes.
- [ ] Add room ownership/locking and abuse prevention for a public release.
- [ ] Create privacy notice, parental consent pathways where applicable.
- [ ] Audit all graphics/assets and accessibility; avoid age-inappropriate content.
- [ ] Perform security audit, load tests, and Android device compatibility tests.

## Free-tier usage warning
Cloudflare has capped daily requests and compute on its free plan. A continuous, heavily active eight-player game may exceed those limits. It is not a free unlimited public server.
