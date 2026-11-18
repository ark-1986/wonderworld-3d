#!/usr/bin/env node
/**
 * WonderWorld 3D free room relay. Node.js built-ins ONLY: no npm, no DB,
 * no payments, no chat, no third-party SDK or account system.
 * 8 players/room, rooms created as needed and held only in memory.
 *
 * Run: node room-server.js
 * Open: http://localhost:8765/ (automatically serves the single HTML game)
 * LAN: http://YOUR_PC_IP:8765/  |  WS: ws://YOUR_PC_IP:8765
 * Internet: deploy on any WebSocket-capable Node host with TLS/WSS.
 */
'use strict';
const http=require('node:http');
const crypto=require('node:crypto');
const fs=require('node:fs');
const path=require('node:path');
const PORT=Number(process.env.PORT||8765),HOST=process.env.HOST||'0.0.0.0';
const MAX_PLAYERS=8,MAX_PACKET=4096;
const ROOM=/^[A-HJ-NP-Z2-9]{8}$/;
const ALIASES=new Set(['Sunny','Rocket','Pixel','Comet','Star','Sprout','Bubbles','Nova']);
const TEAMS=new Set(['Sun','Moon','Stars']);
const rooms=new Map();
const gameFile=path.join(__dirname,'WonderWorld_Team_3D.html');
const replyJSON=(res,status,data)=>{res.writeHead(status,{'content-type':'application/json; charset=utf-8','cache-control':'no-store','access-control-allow-origin':'*'});res.end(JSON.stringify(data));};
const httpServer=http.createServer((req,res)=>{
 const url=new URL(req.url||'/',`http://${req.headers.host||'localhost'}`);
 if(url.pathname==='/health')return replyJSON(res,200,{ok:true,game:'WonderWorld 3D Teams',maxPlayers:MAX_PLAYERS,rooms:rooms.size,noChat:true});
 if(url.pathname==='/'||url.pathname==='/game'){
  if(!fs.existsSync(gameFile))return replyJSON(res,404,{error:'Place WonderWorld_Team_3D.html beside room-server.js'});
  res.writeHead(200,{'content-type':'text/html; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff','content-security-policy':"default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; connect-src 'self' ws: wss:; font-src 'none';"});
  return fs.createReadStream(gameFile).pipe(res);
 }
 replyJSON(res,404,{error:'Not found'});
});
const frame=(payload,opcode=1)=>{
 const body=Buffer.isBuffer(payload)?payload:Buffer.from(String(payload));let header;
 if(body.length<126){header=Buffer.from([0x80|opcode,body.length]);}
 else if(body.length<=65535){header=Buffer.alloc(4);header[0]=0x80|opcode;header[1]=126;header.writeUInt16BE(body.length,2);}
 else{header=Buffer.alloc(10);header[0]=0x80|opcode;header[1]=127;header.writeBigUInt64BE(BigInt(body.length),2);}
 return Buffer.concat([header,body]);
};
function send(peer,message){if(peer.closed||peer.socket.destroyed)return;try{peer.socket.write(frame(JSON.stringify(message)))}catch(e){peer.close()}}
function broadcast(room,msg,except){if(!room)return;for(const p of room.people.values())if(p!==except)send(p,msg)}
function asPublic(peer){return {id:peer.id,n:peer.alias,name:peer.alias,team:peer.team,x:peer.x,y:peer.y,z:peer.z,r:peer.r,eq:peer.eq};}
function closePeer(peer,code=1000,reason='bye'){
 if(peer.closed)return;peer.closed=true;
 try{const msg=Buffer.alloc(2+Math.min(110,reason.length));msg.writeUInt16BE(code,0);msg.write(reason.slice(0,110),2);peer.socket.write(frame(msg,8));}catch(e){}
 try{peer.socket.end();peer.socket.destroy()}catch(e){}
 const room=rooms.get(peer.code);if(room){room.people.delete(peer.id);broadcast(room,{t:'leave',id:peer.id});if(!room.people.size)rooms.delete(peer.code)}
}
function limitNum(v,min,max){return typeof v==='number'&&Number.isFinite(v)?Math.max(min,Math.min(max,v)):null}
function handle(peer,obj){if(!obj||typeof obj!=='object'||Array.isArray(obj))return;
 const room=rooms.get(peer.code);if(!room)return;
 if(obj.t==='ping'){send(peer,{t:'pong'});return}
 if(obj.t==='move'){
  const x=limitNum(obj.x,-58,58),z=limitNum(obj.z,-58,58),y=limitNum(obj.y,-1,12),r=limitNum(obj.r,-100000,100000);
  if([x,y,z,r].some(v=>v===null)||!Number.isFinite(x+z+y+r))return;
  const now=Date.now(),elapsed=Math.max(.04,(now-peer.lastUpdate)/1000),distance=Math.hypot(x-peer.x,z-peer.z);
  // Reject implausible rapid teleports. Normal gameplay allows up to ~10m/s.
  if(distance>Math.max(5,elapsed*19) && now-peer.joined>2500){send(peer,{t:'reject',reason:'movement'});return;}
  peer.x=x;peer.y=y;peer.z=z;peer.r=r;peer.lastUpdate=now;
  const packed={t:'move',id:peer.id,x,y,z,r};
  broadcast(room,packed,peer);return;
 }
 if(obj.t==='outfit'){
  if(typeof obj.eq!=='object'||obj.eq===null||Array.isArray(obj.eq))return;
  const clean={};for(const cat of ['Hats','Shirts','Pants','Trails'])if(typeof obj.eq[cat]==='string'&&new RegExp('^'+cat.toLowerCase()+'-[0-9]{1,2}$').test(obj.eq[cat]))clean[cat]=obj.eq[cat];
  peer.eq=clean;broadcast(room,{t:'outfit',id:peer.id,eq:clean},peer);return;
 }
 if(obj.t==='event'){
  if(obj.kind==='door'&&Number.isInteger(obj.index)&&obj.index>=0&&obj.index<8&&typeof obj.open==='boolean'){
   room.doors[obj.index]=obj.open;broadcast(room,{t:'event',kind:'door',index:obj.index,open:obj.open},peer);
  }else if(obj.kind==='travel'&&obj.dest==='home'){
   peer.x=0;peer.y=0;peer.z=8;peer.lastUpdate=Date.now();broadcast(room,{t:'move',id:peer.id,x:0,y:0,z:8,r:peer.r},peer);
  }else if(obj.kind==='foam'){ // Decorative non-damaging impact only.
   const x=limitNum(obj.x,-58,58),z=limitNum(obj.z,-58,58);
   if(x!==null&&z!==null)broadcast(room,{t:'event',kind:'foam',x,z},peer);
  }
 }
}
function processFrames(peer,chunk){if(peer.closed)return;peer.buffer=Buffer.concat([peer.buffer,chunk]);let count=0;
 while(peer.buffer.length>=2&&count++<80){const b=peer.buffer,f1=b[0],f2=b[1],opcode=f1&15,fin=!!(f1&0x80),masked=!!(f2&0x80);let length=f2&127,off=2;
  if(!fin){closePeer(peer,1003,'fragmented frames unsupported');return;}
  if(length===126){if(b.length<4)return;length=b.readUInt16BE(2);off=4;}
  else if(length===127){if(b.length<10)return;const big=b.readBigUInt64BE(2);if(big>BigInt(MAX_PACKET)){closePeer(peer,1009,'message too large');return;}length=Number(big);off=10;}
  if(!masked){closePeer(peer,1002,'unmasked browser frame');return;}
  if(length>MAX_PACKET){closePeer(peer,1009,'message too large');return;}
  if(b.length<off+4+length)return;
  const mask=b.subarray(off,off+4),payload=Buffer.from(b.subarray(off+4,off+4+length));for(let i=0;i<length;i++)payload[i]^=mask[i%4];peer.buffer=b.subarray(off+4+length);
  if(opcode===8){closePeer(peer,1000,'client left');return;}
  if(opcode===9){sendControl(peer,payload,10);continue;}
  if(opcode===10){peer.lastPong=Date.now();continue;}
  if(opcode!==1)continue;
  try{const obj=JSON.parse(payload.toString('utf8'));handle(peer,obj)}catch(e){}
 }
}
function sendControl(peer,body,opcode){if(peer.closed)return;try{peer.socket.write(frame(body,opcode))}catch(e){closePeer(peer)}}
httpServer.on('upgrade',(req,socket)=>{
 const url=new URL(req.url||'/',`http://${req.headers.host||'localhost'}`),match=/^\/room\/([^/]+)$/.exec(url.pathname);
 if(!match||!ROOM.test(match[1])||req.headers.upgrade?.toLowerCase()!=='websocket'||typeof req.headers['sec-websocket-key']!=='string'){
  socket.end('HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n');return;
 }
 const code=match[1],room=rooms.get(code)||{code,people:new Map(),doors:{}};
 if(room.people.size>=MAX_PLAYERS){socket.end('HTTP/1.1 429 Too Many Requests\r\nConnection: close\r\n\r\nRoom is full');return;}
 const accept=crypto.createHash('sha1').update(req.headers['sec-websocket-key']+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
 socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: '+accept+'\r\n\r\n');
 const alias=ALIASES.has(url.searchParams.get('alias'))?url.searchParams.get('alias'):'Sunny';const team=TEAMS.has(url.searchParams.get('team'))?url.searchParams.get('team'):'Sun';
 const id=crypto.randomUUID(),peer={id,socket,code,alias,team,x:0,y:0,z:8,r:0,eq:{},closed:false,buffer:Buffer.alloc(0),joined:Date.now(),lastUpdate:Date.now(),lastPong:Date.now()};
 const roster=[...room.people.values()].map(asPublic);room.people.set(id,peer);rooms.set(code,room);
 send(peer,{t:'welcome',id,room:code,team,players:roster,doors:room.doors});broadcast(room,{t:'join',player:asPublic(peer)},peer);
 socket.on('data',chunk=>processFrames(peer,chunk));socket.on('close',()=>closePeer(peer));socket.on('end',()=>closePeer(peer));socket.on('error',()=>closePeer(peer));
});
// Keep-alive and memory cleanup.
const keepalive=setInterval(()=>{const now=Date.now();for(const room of rooms.values())for(const peer of room.people.values()){
 if(now-peer.lastPong>80000){closePeer(peer,1001,'idle');continue;}sendControl(peer,Buffer.from('ww'),9);
}},30000);keepalive.unref();
httpServer.listen(PORT,HOST,()=>console.log(`WonderWorld relay: http://localhost:${PORT} | WebSocket ws://localhost:${PORT} | 8 players/room`));
