"""Dependency-free static integrity check; does not replace running Godot/Android."""
from pathlib import Path
import json,re,struct,sys
base=Path(__file__).resolve().parent.parent
root=base/'godot'
assert (root/'project.godot').exists()
assert (root/'export_presets.cfg').exists()
assert (base/'.github/workflows/android-debug-apk.yml').exists()
for path in ['scenes/main.tscn','scripts/avatar.gd','scripts/city_minimap.gd','scripts/game.gd','scripts/network.gd','scripts/virtual_joystick.gd','scripts/wonder_city.gd','assets/coin.wav','assets/happy_loop.wav','assets/icon.png']:
    assert (root/path).is_file(),path
for name in ['grass','roof','plaster','road','cobble','water']:
    assert (root/f'assets/textures/{name}.png').is_file(),name
models=['festival_gate','candy_kiosk','ferris_wheel','lantern_post','park_bench','balloon_cart','pet_house','trophy_portal','flower_bed','magic_tower','palm_tree']
triangles_total=0
for name in models:
    f=root/'assets/models'/f'{name}.glb'
    b=f.read_bytes()
    assert b[:4]==b'glTF',name
    version,length=struct.unpack_from('<II',b,4)
    assert version==2 and length==len(b),(name,version,length,len(b))
    chunk_length,chunk_type=struct.unpack_from('<I4s',b,12)
    assert chunk_type==b'JSON'
    gltf=json.loads(b[20:20+chunk_length].decode('utf-8').rstrip(' \x00'))
    assert gltf['meshes'],name
    assert gltf['accessors'],name
    assert (b'COLOR_0' in b[20:20+chunk_length]), name+' has no colors'
assert (root/'scripts/wonder_city.gd').read_text().count('_spawn_model(')>10
for path in [root/'scripts/game.gd',root/'scenes/main.tscn',root/'scripts/wonder_city.gd']:
    contents=path.read_text()
    for p in re.findall(r'res://([^"\'\s\)]+)',contents):
        if p.endswith('.gd') or p.endswith('.png') or p.endswith('.wav') or p.endswith('.tscn'):
            assert (root/p).exists(),f'{path}: {p}'
g=(root/'scripts/game.gd').read_text()
assert 'func _quick_travel()' in g and 'network.request_travel(stop)' in g and 'travel_pending' in g
n=(root/'scripts/network.gd').read_text()
assert 'func request_travel(stop: int)' in n
srv=(base/'server/src/index.ts').read_text()
assert 'const WORLD_LIMIT = 56' in srv and 'TRAVEL_STOPS' in srv and 'msg.t === "travel"' in srv
assert 'TRAVEL_STOPS' in g
assert 'import_etc2_astc=true' in (root/'project.godot').read_text()
assert 'architectures/arm64-v8a=true' in (root/'export_presets.cfg').read_text()
print(f'PASS static package integrity: {len(models)} GLB hero models, scripts, textures, scene, validated destinations, Android export settings')
print('NOTE: Static integrity DOES NOT prove game compiles in Godot or runs well on a phone.')
