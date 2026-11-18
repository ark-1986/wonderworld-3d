#!/usr/bin/env node
// Offline, zero-dependency end-to-end tests of the WebSocket room relay.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createServer} from 'node:net';
import {setTimeout as sleep} from 'node:timers/promises';
const freePort=()=>new Promise((ok,fail)=>{
  const s=createServer();s.once('error',fail);s.listen(0,'127.0.0.1',()=>{
    const p=s.address().port;s.close(()=>ok(p));
  });
});
const port=await freePort();
const base='http://127.0.0.1:'+port;
const relay=spawn(process.execPath,[new URL('./room-server.js',import.meta.url).pathname],{
  env:{...process.env,PORT:String(port),HOST:'127.0.0.1'},stdio:['ignore','pipe','pipe']
});
let log='';relay.stdout.on('data',x=>log+=x);relay.stderr.on('data',x=>log+=x);
const sockets=[];
async function serverReady(){
  for(let t=0;t<60;t++){
    if(relay.exitCode!==null)throw Error('Relay exited: '+log);
    try{const res=await fetch(base+'/health');if(res.ok)return res.json();}catch{}
    await sleep(100);
  }
  throw Error('Relay not listening: '+log);
}
function join(name,team,room='ABCDEFG2'){
  const ws=new WebSocket(base.replace('http:','ws:')+'/room/'+room+'?alias='+name+'&team='+team);
  sockets.push(ws);
  const msgs=[],waiters=[];
  ws.addEventListener('error',()=>{});
  ws.addEventListener('message',event=>{
    let msg;try{msg=JSON.parse(event.data)}catch{return}
    msgs.push(msg);
    for(const x of [...waiters])if(x.filter(msg)){clearTimeout(x.timer);waiters.splice(waiters.indexOf(x),1);x.resolve(msg);}
  });
  return {ws,msgs,
    send:m=>ws.send(JSON.stringify(m)),
    find:(filter,ms=6000)=>{
      const prior=msgs.find(filter);if(prior)return Promise.resolve(prior);
      return new Promise((resolve,reject)=>{
        const x={filter,resolve,timer:setTimeout(()=>reject(Error('No expected message; got '+JSON.stringify(msgs))),ms)};
        waiters.push(x);
      });
    }
  };
}
try{
  const health=await serverReady();
  assert.equal(health.ok,true);
  assert.equal(health.maxPlayers,8);
  assert.equal((await fetch(base+'/')).status,200);
  const a=join('Sunny','Sun');
  const aw=await a.find(m=>m.t==='welcome');
  assert.equal(aw.players.length,0);
  const b=join('Rocket','Moon');
  const bw=await b.find(m=>m.t==='welcome');
  assert.equal(bw.team,'Moon');
  assert.equal(bw.players.length,1);
  assert.equal((await a.find(m=>m.t==='join')).player.team,'Moon');
  a.send({t:'move',x:1.5,y:0,z:8,r:0.15});
  assert.equal((await b.find(m=>m.t==='move'&&m.id===aw.id)).x,1.5);
  a.send({t:'outfit',eq:{Hats:'hats-2',Pants:'pants-4'}});
  assert.equal((await b.find(m=>m.t==='outfit'&&m.id===aw.id)).eq.Hats,'hats-2');
  b.send({t:'event',kind:'door',index:0,open:true});
  assert.equal((await a.find(m=>m.t==='event'&&m.kind==='door')).open,true);
  const c=join('Star','Stars');
  const cw=await c.find(m=>m.t==='welcome');
  assert.equal(cw.players.length,2);
  assert.equal(cw.players[0].eq.Hats,'hats-2');
  assert.equal(cw.doors[0],true);
  const differentRoom=join('Pixel','Sun','HHHH3333');
  assert.equal((await differentRoom.find(m=>m.t==='welcome')).players.length,0);
  for(let i=0;i<5;i++)await join('Comet','Sun').find(m=>m.t==='welcome');
  const ninth=new WebSocket(base.replace('http:','ws:')+'/room/ABCDEFG2?alias=Nova');
  let denied=false;
  await new Promise(done=>{
    const timer=setTimeout(done,2500);
    ninth.addEventListener('error',()=>{denied=true;clearTimeout(timer);done();},{once:true});
    ninth.addEventListener('open',()=>{clearTimeout(timer);done();},{once:true});
  });
  assert.equal(denied,true,'ninth player must not join');
  a.ws.close();
  assert.equal((await b.find(m=>m.t==='leave'&&m.id===aw.id)).t,'leave');
  console.log('PASS multiplayer: two teams same room, live movement, outfits, shared door, late join, isolated rooms, eight-player cap, clean leave.');
}finally{
  for(const ws of sockets)try{ws.close()}catch{}
  relay.kill('SIGTERM');
  await sleep(80);
}
