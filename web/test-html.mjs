import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Script} from 'node:vm';
const html=readFileSync(new URL('./WonderWorld_Team_3D.html',import.meta.url),'utf8');
assert.ok(html.length>500000,'Inline 3D engine appears missing');
assert.ok(/<canvas\b/i.test(html),'Canvas rendering element missing');
assert.ok(!/<script[^>]*\bsrc\s*=/i.test(html),'Game may not require external scripts');
assert.ok(!/<link[^>]*\brel=["']?stylesheet[^>]*\bhref\s*=/i.test(html),'No external stylesheets allowed');
for(const id of ['scene','playBtn','joyBase','jumpBtn','runBtn','shopOverlay','shopTabs','shopGrid','createRoom','joinRoom','serverUrl','roomCode','aliasSelect','teamSelect']){
 assert.ok(html.includes('id="'+id+'"'),'Missing UI element: '+id);
}
const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)];
assert.ok(scripts.length>=2,'Expected inline 3D library and game logic');
for(let i=0;i<scripts.length;i++)new Script(scripts[i][1],{filename:'inline-script-'+i+'.js'});
for(const marker of ['function connectTeam(','function handleNet(','function drawShop(','function makeWorld(','window.WonderWorldTest','localStorage','requestAnimationFrame','remoteActors']){
 assert.ok(html.includes(marker),'Missing feature marker '+marker);
}
console.log('PASS HTML: self-contained engine, valid JavaScript syntax, touch UI, offline shop, online team controls, remote avatars.');
