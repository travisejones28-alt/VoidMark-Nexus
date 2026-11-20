local _, N = ...
-- Live character sync between paired characters on separate accounts.
--
-- Uses the game's addon whisper channel (C_ChatInfo.SendAddonMessage), which
-- works between any two online characters on the same realm and faction,
-- including characters on different accounts. Data is only accepted from
-- character names you paired on BOTH sides with /vmn pair NAME. Payloads use the
-- same bounded, non-executable format and validation as manual export/import.
-- Nothing is sent while the peer is offline; manual export/import still works.

local PREFIX='VMNX'
local CHUNK=230          -- payload bytes per message (limit is 255 incl. header)
local PER_TICK=4         -- messages per 0.25 s; well under client throttles
local MAX_CHUNKS=9000    -- ~2 MB, matching the import limit
N.syncPrefix=PREFIX

-- One key for a character however the client writes it: "Voidmark Bank",
-- "Voidmark-Bank" (surname in the realm slot) or "Voidmark Bank-Realm".
local function shortName(name)
 if type(name)~='string' or name=='' then return nil end
 local s=name:lower()
 local realm=((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ''):gsub('%s',''):lower()
 if realm~='' then
  local base,tail=s:match('^(.-)%-([^%-]+)$')
  if base and base~='' and tail:gsub('%s','')==realm then s=base end
 end
 s=s:gsub('%-',' '):gsub('%s+',' '):match('^%s*(.-)%s*$')
 return s~='' and s or nil
end
N.SyncKey=shortName
-- Whisper the other character as "First Surname", or as "First-Surname" when
-- that form is what reaches them. Until they answer, probes alternate forms.
function N:SyncTarget(peer)
 local name=type(self.db.sync.peers[peer])=='string' and self.db.sync.peers[peer] or peer
 local hyphen=self.syncHyphen and self.syncHyphen[peer]
 if hyphen then return (name:gsub(' ','-',1)) end
 return name
end

function N:InitializeSync()
 local d=self.db
 if type(d.sync)~='table' then d.sync={} end
 if type(d.sync.peers)~='table' then d.sync.peers={} end
 if type(d.sync.known)~='table' then d.sync.known={} end
 -- Section hashes persist so a reload does not resend unchanged data.
 self.syncIn,self.syncOut,self.syncHashes,self.syncSeq={},{},d.sync.known,0
 self:AutoPair()
 if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then self:Call(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX)
 elseif RegisterAddonMessagePrefix then self:Call(RegisterAddonMessagePrefix,PREFIX) end
 if ChatFrame_AddMessageEventFilter and not self.syncFilter then
  self.syncFilter=true
  -- Hide "No player named X is currently playing" for our own probes only.
  ChatFrame_AddMessageEventFilter('CHAT_MSG_SYSTEM',function(_,_,msg)
   if type(msg)~='string' or not N.syncProbeUntil or (GetTime and GetTime() or 0)>N.syncProbeUntil then return false end
   local m=msg:lower()
   for peer in pairs(N.db.sync.peers) do if m:find(peer,1,true) or m:find((peer:gsub(' ','-',1)),1,true) then return true end end
   return false
  end)
 end
end

-- The two VoidMark characters pair themselves the first time (same as Market).
local AUTO={['voidmark soulreaver']='Voidmark Bank',['voidmark bank']='Voidmark Soulreaver'}
function N:AutoPair()
 local s=self.db.sync
 if s.autoPairSeen then return end
 local other=AUTO[shortName(self.character and self.character.name) or '']
 if not other then return end
 s.autoPairSeen=true
 if not next(s.peers) then s.peers[shortName(other)]=other end
end

function N:PairPeer(name)
 if type(name)=='string' then name=name:match('^%s*(.-)%s*$'):gsub(' +',' ') end
 local key=shortName(name)
 if not key or key=='' then
  local list={};for p in pairs(self.db.sync.peers) do list[#list+1]=p end
  return self:Print('Paired: '..(#list>0 and table.concat(list,', ') or 'none')..'. Use /vmn pair NAME on both characters.')
 end
 if key==shortName(self.character.name) then return self:Print('Pair with the character on your other account.') end
 if not key:find(' ',1,true) then self:Print('Use the full name with surname, e.g. /vmn pair Voidmark Bank.') end
 -- Keep the name as typed, minus a realm suffix, with the surname space restored.
 local display=name
 local realm=((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ''):gsub('%s',''):lower()
 local base,tail=display:match('^(.-)%-([^%-]+)$')
 if base and base~='' and tail:gsub('%s',''):lower()==realm then display=base end
 self.db.sync.peers[key]=(display:gsub('%-',' '))
 self.dirty=true
 self:Print('Paired with '..self.db.sync.peers[key]..'. Pair this character on the other account too, then both sync while online.')
 self:SyncHello(key)
end
function N:UnpairPeer(name)
 local key=shortName(name);if not key then return end
 self.db.sync.peers[key]=nil;self:Print('Unpaired '..key..'. Their last synced record is kept; delete it from Characters if unwanted.')
end

-- Avoid probing a peer known to be offline through the friends list.
function N:PeerMaybeOnline(peer)
 local api=C_FriendList
 if api and api.GetFriendInfo then
  local info=self:Call(api.GetFriendInfo,peer)
  if type(info)=='table' and info.connected==false then return false end
 end
 return true
end

function N:SendSync(peer,msg)
 local q=self.syncOut[peer] or {};self.syncOut[peer]=q;q[#q+1]=msg
 if not self.syncTicker and C_Timer and C_Timer.NewTicker then
  self.syncTicker=C_Timer.NewTicker(.25,function() N:Guard('sync send',function() N:FlushSync() end) end)
 end
end
-- Newer clients allow a short burst of addon messages, then roughly one per
-- second, and DROP anything over that. A throttled message stays queued and is
-- retried after a pause instead of being lost (which left sync half-finished).
local THROTTLED={[3]=true,[8]=true} -- AddonMessageThrottle, ChannelThrottle
function N:SendResult(ok,result)
 if not ok then return 'failed' end
 if result==nil or result==true or result==0 then return 'sent' end
 if result==false or THROTTLED[result] then return 'throttled' end
 return 'failed'
end
function N:FlushSync()
 local send=C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
 local now=GetTime and GetTime() or 0
 local stats=self.syncStats or {sent=0,throttled=0,failed=0};self.syncStats=stats
 local any=false
 for peer,q in pairs(self.syncOut) do
  if (self.syncPauseUntil or 0)<=now then
   for _=1,PER_TICK do
    local msg=q[1];if not msg then break end
    self.syncProbeUntil=now+3
    local target=self:SyncTarget(peer)
    local state='failed'
    if type(send)=='function' then state=self:SendResult(pcall(send,PREFIX,msg,'WHISPER',target)) end
    if state=='throttled' then
     stats.throttled=stats.throttled+1
     self.syncPauseUntil=now+1.2 -- keep msg at the front; retry after the client refills
     break
    end
    table.remove(q,1)
    stats[state]=stats[state]+1
   end
  end
  if #q>0 then any=true else self.syncOut[peer]=nil end
 end
 if not any and self.syncTicker then self.syncTicker:Cancel();self.syncTicker=nil end
end

-- Escape bytes that are unsafe in chat-channel payloads; reversed after reassembly.
local function escape(raw) return (raw:gsub('~','~~'):gsub('%z','~0'):gsub('\n','~n'):gsub('\r','~r')) end
local function unescape(raw)
 return (raw:gsub('~(.)',function(c) return c=='~' and '~' or c=='0' and '\0' or c=='n' and '\n' or c=='r' and '\r' or '' end))
end
N.SyncEscape,N.SyncUnescape=escape,unescape
local function hash(text)
 local h=5381
 for i=1,#text,7 do h=(h*33+text:byte(i))%4294967291 end
 return tostring(#text)..'-'..tostring(h)
end
N.SyncHash=hash
-- Sections are hashed so unchanged data is never resent.
function N:SyncSections()
 local c=self:CleanImported(self.character)
 c.account=self.db.account;c.imported=nil
 local inv={bags=c.bags,bank=c.bank,bagsAt=c.bagsAt,bankAt=c.bankAt,money=c.money,moneyAt=c.moneyAt,mail=c.mail,mailAt=c.mailAt,equipped=c.equipped,equippedAt=c.equippedAt}
 local id={name=c.name,realm=c.realm,faction=c.faction,guid=c.guid,account=c.account,at=c.at}
 local out={}
 -- Every other character on this account rides along ("alts"), so pairing
 -- one character per account shares the whole account.
 local alts={}
 for cid,o in pairs(self.db.characters) do
  if cid~=self.characterID and not o.imported and not o.synced and type(o.name)=='string' then
   local a=self:CleanImported(o);a.account=self.db.account;a.imported=nil;a.synced=nil;alts[#alts+1]=a
  end
 end
 table.sort(alts,function(a,b) return a.name<b.name end)
 for key,value in pairs({id=id,inv=inv,prof={professions=c.professions,cooldowns=c.cooldowns},alts=alts}) do
  local raw=self:EncodeData(value);out[key]={raw=raw,hash=hash(raw)}
 end
 -- Recorded recipe sources (RecipeSync.lua): re-encoded only after they change.
 out.recipes=self:RecipeSyncSection(hash)
 return out
end

function N:SyncHello(peer)
 if not self.db.sync.peers[peer] or not self:PeerMaybeOnline(peer) then return end
 local s=self:SyncSections();self.syncSections=s
 self:SyncNote(peer,'hello')
 self:SendSync(peer,'H:'..self.db.account..':'..s.id.hash..':'..s.inv.hash..':'..s.prof.hash)
 self:SendSync(peer,'A:'..s.alts.hash)
 -- Separate message: older versions ignore it and never ask for 'recipes'.
 self:SendSync(peer,'F:'..s.recipes.hash)
end
function N:SyncAll()
 for peer in pairs(self.db.sync.peers) do self:SyncHello(peer) end
end
-- Debounced: called after bag/bank/mail/profession changes. Sends about 5s
-- after things settle, at most once every 15s (only changed parts are sent).
local SOON,MIN_GAP=5,15
function N:SyncSoon()
 if not next(self.db.sync and self.db.sync.peers or {}) then return end
 if self.syncPending then return end
 self.syncPending=true
 local now=GetTime and GetTime() or 0
 local wait=math.max(SOON,(self.syncLastSoon or -1e9)+MIN_GAP-now)
 local function run() self.syncPending=false;self.syncLastSoon=GetTime and GetTime() or 0;self:Guard('sync',function() N:SyncAll() end) end
 if C_Timer and C_Timer.After then C_Timer.After(wait,run) else run() end
end

-- Background retry so syncing never waits on a button: until the other
-- character answers, say hello every minute (one tiny message); after that,
-- check in every 5 minutes. Unchanged data is never resent (hashes match).
local PROBE,CHECKIN=60,300
function N:SyncTick(now)
 now=now or (GetTime and GetTime() or 0)
 self.syncContact=self.syncContact or {}; self.syncProbeAt=self.syncProbeAt or {}
 for peer in pairs(self.db.sync and self.db.sync.peers or {}) do
  local last=self.syncContact[peer]
  local wait=(last and now-last<CHECKIN*2) and CHECKIN or PROBE
  if not (self.syncOut and self.syncOut[peer]) and now-(self.syncProbeAt[peer] or -1e9)>=wait then
   self.syncProbeAt[peer]=now
   self.syncHyphen=self.syncHyphen or {}; self.syncHelloForm=self.syncHelloForm or {}
   self.syncHelloForm[peer]=self.syncHyphen[peer] or false
   self:SyncHello(peer)
   if not last then self.syncHyphen[peer]=not self.syncHyphen[peer] end -- unanswered: try the other name form next
  end
 end
end
function N:SyncConnected(peer)
 local last=self.syncContact and self.syncContact[peer]
 return last and ((GetTime and GetTime() or 0)-last)<600
end

function N:SendSection(peer,key)
 local s=self.syncSections or self:SyncSections();self.syncSections=s
 local raw=s[key] and s[key].raw;if not raw then return end
 raw=escape(raw)
 local n=math.ceil(#raw/CHUNK);if n>MAX_CHUNKS then return self:Print('Sync data too large to send.') end
 self.syncSeq=(self.syncSeq%999)+1
 for i=1,n do
  self:SendSync(peer,string.format('D:%d:%s:%d:%d:',self.syncSeq,key,i,n)..raw:sub((i-1)*CHUNK+1,i*CHUNK))
 end
end

-- Stored record for a peer account's character, applied section by section.
function N:ApplySync(peer,key,data)
 local state=self.syncIn[peer];if not state or not state.account then return end
 local pending=state.record
 if not pending then
  -- Continue from the last record received from this peer account, so an
  -- inventory-only update can be applied without resending identity.
  pending={professions={},bags={},bank={}}
  for _,c in pairs(self.db.characters) do
   if c.synced and c.account==state.account and shortName(c.name)==peer then pending=self:Copy(c);pending.imported,pending.synced,pending.syncedAt=nil,nil,nil end
  end
  state.record=pending
 end
 -- 0.11: newer wins, per part. A delayed or replayed message can never put an
 -- older bag, bank, mail, gold or profession snapshot over a newer one.
 local function newer(incoming,current)
  local a,b=tonumber(incoming),tonumber(current)
  if not b then return true end
  if not a then return false end
  return a>=b
 end
 local older=0
 if key=='id' then
  for _,k in ipairs({'name','realm','faction','guid','account','at'}) do pending[k]=data[k] end
 elseif key=='inv' then
  if newer(data.bagsAt,pending.bagsAt) then pending.bags,pending.bagsAt=data.bags or {},data.bagsAt else older=older+1 end
  if newer(data.bankAt,pending.bankAt) then pending.bank,pending.bankAt=data.bank or {},data.bankAt else older=older+1 end
  if data.money~=nil then if newer(data.moneyAt,pending.moneyAt) then pending.money,pending.moneyAt=data.money,data.moneyAt else older=older+1 end end
  if data.mail~=nil then if newer(data.mailAt,pending.mailAt) then pending.mail,pending.mailAt=data.mail,data.mailAt else older=older+1 end end
  if data.equipped~=nil then if newer(data.equippedAt,pending.equippedAt) then pending.equipped,pending.equippedAt=data.equipped,data.equippedAt else older=older+1 end end
 elseif key=='prof' then
  local merged={}
  for pid,p in pairs(pending.professions or {}) do merged[pid]=p end
  for pid,p in pairs(data.professions or {}) do
   local cur=merged[pid]
   if type(cur)~='table' or type(p)~='table' or newer(p.at,cur.at) then merged[pid]=p else older=older+1 end
  end
  pending.professions=merged
  if data.cooldowns~=nil then pending.cooldowns=data.cooldowns end
 end
 if older>0 then self:SyncNote(peer,'older',older) end
 if not pending.name then return end
 if shortName(pending.name)~=peer then return self:Print('Ignored sync: sender name does not match its data.') end
 if pending.account~=state.account or pending.account==self.db.account then return end
 -- A paired character is on this realm and faction (whispers need both), so a
 -- missing name, realm or faction is filled from what we know instead of
 -- throwing away every sync. Happens when the other client saved its identity
 -- before the game had the realm or faction ready.
 local function blank(v) return type(v)~='string' or v=='' or v=='Unknown' end
 local me=self.character or {}
 if blank(pending.realm) then pending.realm=me.realm end
 if blank(pending.faction) then pending.faction=me.faction end
 local id=pending.account..'/'..tostring(pending.realm)..'/'..pending.name
 local existing=self.db.characters[id]
 -- Start from the last synced record so sections can arrive separately.
 local merged=existing and existing.synced and self:Copy(existing) or {professions={},bags={},bank={}}
 for k,v in pairs(pending) do merged[k]=v end
 self:FixFutureTimes(merged)
 local ok,err=pcall(self.ValidateCharacter,self,merged)
 if not ok then
  -- Say it once per peer and problem, not on every message.
  err=tostring(err):gsub('^.-:%d+: ','')
  self.syncWarned=self.syncWarned or {}
  local key=peer..'|'..err
  if self.syncWarned[key] then return end
  self.syncWarned[key]=true
  return self:Print('Ignored sync from '..(self.db.sync.peers[peer] or peer)..': '..err)
 end
 for otherID,other in pairs(self.db.characters) do
  if otherID~=id and not other.imported and other.realm==merged.realm and other.name==merged.name then
   return self:Print('Ignored sync for '..merged.name..': a local character has that identity.')
  end
 end
 local clean=self:CleanImported(merged);clean.imported=true;clean.synced=true;clean.syncedAt=self:Now()
 self.db.characters[id]=clean;self.dirty=true;self.renderStocks=nil
 state.applied=(state.applied or 0)+1
 self:SyncNote(peer,'ok')
end

-- 0.11 diagnostics kept across reloads: last successful apply, last contact,
-- how many older snapshots were refused.
function N:SyncNote(peer,what,n)
 local d=self.db.sync;if type(d.status)~='table' then d.status={} end
 local st=type(d.status[peer])=='table' and d.status[peer] or {};d.status[peer]=st
 if what=='ok' then st.lastOk=self:Now();st.applied=(st.applied or 0)+1
 elseif what=='contact' then st.lastContact=self:Now()
 elseif what=='hello' then st.lastHello=self:Now();st.hellos=(st.hellos or 0)+1
 elseif what=='older' then st.olderRefused=(st.olderRefused or 0)+(n or 1);st.lastOlder=self:Now() end
 return st
end

-- The paired account's other characters (sent with the sync).
function N:ApplyAlts(peer,list)
 local state=self.syncIn[peer];if not state or not state.account or type(list)~='table' then return end
 local n=0
 for i=1,math.min(#list,50) do
  local a=list[i]
  if type(a)=='table' and type(a.name)=='string' and type(a.realm)=='string' and a.account==state.account and a.account~=self.db.account then
   local local_=false
   for _,o in pairs(self.db.characters) do if not o.imported and o.realm==a.realm and o.name==a.name then local_=true end end
   local realm=(a.realm=='' or a.realm=='Unknown') and (self.character and self.character.realm) or a.realm
   local key=a.account..'/'..realm..'/'..a.name
   local have=self.db.characters[key]
   local function stamp(c) return math.max(tonumber(c.at) or 0,tonumber(c.bagsAt) or 0,tonumber(c.bankAt) or 0) end
   if have and have.synced and stamp(have)>stamp(a) then local_=true;self:SyncNote(peer,'older') end
   if not local_ then
    local rec=self:Copy(a);rec.imported,rec.synced=nil,nil
    -- Same realm and faction as the paired character (see ApplySync).
    local me=self.character or {}
    if rec.realm=='' or rec.realm=='Unknown' then rec.realm=me.realm end
    if type(rec.faction)~='string' or rec.faction=='' or rec.faction=='Unknown' then rec.faction=me.faction end
    self:FixFutureTimes(rec)
    local ok=pcall(self.ValidateCharacter,self,rec)
    if ok then
     local clean=self:CleanImported(rec);clean.imported=true;clean.synced=true;clean.syncedAt=self:Now();clean.via=peer
     self.db.characters[key]=clean;n=n+1
    end
   end
  end
 end
 if n>0 then self.dirty=true;self.renderStocks=nil end
end

function N:SyncReceive(prefix,msg,channel,sender)
 if prefix~=PREFIX or channel~='WHISPER' or type(msg)~='string' then return end
 local peer=shortName(sender)
 if not peer or not self.db.sync.peers[peer] then
  if peer then self.syncIgnored=sender end
  return
 end
 self.syncContact=self.syncContact or {}
 if not self.syncContact[peer] and self.syncHelloForm and self.syncHelloForm[peer]~=nil then
  self.syncHyphen=self.syncHyphen or {}; self.syncHyphen[peer]=self.syncHelloForm[peer] -- keep the form that got through
 end
 self.syncContact[peer]=GetTime and GetTime() or 0
 self:SyncNote(peer,'contact')
 local kind=msg:sub(1,2)
 if kind=='H:' or kind=='R:' then
  local account,idh,invh,profh=msg:match('^[HR]:([^:]+):([^:]+):([^:]+):([^:]+)$')
  if not account or account==self.db.account or #account>80 then return end
  local state=self.syncIn[peer] or {};self.syncIn[peer]=state;state.account=account
  local known=self.syncHashes[peer] or {};self.syncHashes[peer]=known
  local have=false
  for _,c in pairs(self.db.characters) do if c.synced and c.account==account and shortName(c.name)==peer then have=true end end
  if not have or known.account~=account then known={account=account};self.syncHashes[peer]=known end
  -- Request only sections we have not already applied.
  local want={}
  if known.id~=idh then want[#want+1]='id' end
  if known.inv~=invh then want[#want+1]='inv' end
  if known.prof~=profh then want[#want+1]='prof' end
  state.expect={id=idh,inv=invh,prof=profh}
  if #want>0 then self:SendSync(peer,'Q:'..table.concat(want,',')) end
  if kind=='H:' then
   local s=self:SyncSections();self.syncSections=s
   self:SendSync(peer,'R:'..self.db.account..':'..s.id.hash..':'..s.inv.hash..':'..s.prof.hash)
   self:SendSync(peer,'A:'..s.alts.hash)
   self:SendSync(peer,'F:'..s.recipes.hash)
  end
 elseif kind=='F:' then
  local h=msg:match('^F:([%w%-]+)$')
  local state=self.syncIn[peer];if not h or not state or not state.account then return end
  local known=self.syncHashes[peer] or {};self.syncHashes[peer]=known
  if known.recipes~=h then self:SendSync(peer,'Q:recipes') end
 elseif kind=='A:' then
  -- Separate message so older versions simply ignore it.
  local h=msg:match('^A:([%w%-]+)$')
  local state=self.syncIn[peer];if not h or not state or not state.account then return end
  local known=self.syncHashes[peer] or {};self.syncHashes[peer]=known
  if known.alts~=h then self:SendSync(peer,'Q:alts') end
 elseif kind=='Q:' then
  local list=msg:sub(3)
  -- id first so a new peer record is complete as early as possible.
  for _,key in ipairs({'id','inv','prof','alts','recipes'}) do if list:find(key,1,true) then self:SendSection(peer,key) end end
 elseif kind=='D:' then
  local seq,key,i,n,body=msg:match('^D:(%d+):(%a+):(%d+):(%d+):(.*)$')
  i,n=tonumber(i),tonumber(n)
  if not seq or (key~='id' and key~='inv' and key~='prof' and key~='alts' and key~='recipes') or not i or not n or n<1 or n>MAX_CHUNKS or i<1 or i>n then return end
  local state=self.syncIn[peer];if not state or not state.account then return end
  local buf=state[key]
  if not buf or buf.seq~=seq or buf.n~=n then buf={seq=seq,n=n,parts={},got=0};state[key]=buf end
  if not buf.parts[i] then buf.parts[i]=body;buf.got=buf.got+1 end
  if buf.got==n then
   state[key]=nil
   local raw=unescape(table.concat(buf.parts))
   local ok,data=pcall(self.Decode,self,raw)
   if not ok or type(data)~='table' then return self:Print('Ignored damaged sync data from '..peer..'.') end
   if key=='alts' then self:ApplyAlts(peer,data) elseif key=='recipes' then
    local n,err=self:MergeRecipeSources(data); if not n then return self:Print('Ignored invalid recipe sync: '..tostring(err)) end
   else self:ApplySync(peer,key,data) end
   local known=self.syncHashes[peer] or {};self.syncHashes[peer]=known
   known[key]=hash(raw)
  end
 end
end

function N:SyncStatus()
 local lines={'Live sync (addon whisper; same realm and faction; both characters online at the same time).'}
 local any=false
 local now=self:Now()
 for peer,display in pairs(self.db.sync.peers) do
  any=true
  local st=type(self.db.sync.status)=='table' and self.db.sync.status[peer] or {}
  local rec
  for _,c in pairs(self.db.characters) do if c.synced and shortName(c.name)==peer and (not rec or (c.syncedAt or 0)>(rec.syncedAt or 0)) then rec=c end end
  local name=type(display)=='string' and display or peer
  lines[#lines+1]=''
  lines[#lines+1]=name..': '..self:PeerState(peer)
  lines[#lines+1]='  Last successful sync: '..(st.lastOk and self:Ago(st.lastOk) or rec and rec.syncedAt and self:Ago(rec.syncedAt) or 'never')
  lines[#lines+1]='  Last heard from: '..(st.lastContact and self:Ago(st.lastContact) or 'never')..'; last hello sent: '..(st.lastHello and self:Ago(st.lastHello) or 'never')
  if rec then
   local age=self.db.settings.inventoryAge
   local function part(label,at) return label..' '..(at and self:Ago(at) or 'never')..((at and now-at>age) and ' (STALE: not counted unless you allow stale data)' or '') end
   lines[#lines+1]='  Their data: '..part('bags',rec.bagsAt)..', '..part('bank',rec.bankAt)
  end
  if (st.olderRefused or 0)>0 then lines[#lines+1]='  Older snapshots refused (newer data kept): '..st.olderRefused end
  local q=self.syncOut and self.syncOut[peer]
  if q and #q>0 then lines[#lines+1]='  Outstanding: '..#q..' message'..(#q==1 and '' or 's')..' waiting to send' end
  local inbound=self.syncIn and self.syncIn[peer]
  if inbound then for _,k in ipairs({'id','inv','prof','alts'}) do local b=inbound[k];if type(b)=='table' and b.n then lines[#lines+1]=string.format('  Receiving %s: %d of %d parts',k,b.got or 0,b.n) end end end
 end
 if not any then lines[#lines+1]='No paired characters. On each account type /vmn pair OTHERNAME.' end
 local st=self.syncStats
 if st then
  local waiting=0;for _,q in pairs(self.syncOut or {}) do waiting=waiting+#q end
  lines[#lines+1]=''
  lines[#lines+1]=string.format('This session: sent %d, waiting %d, slowed down %d times, failed %d.',st.sent,waiting,st.throttled,st.failed)
 end
 local dups=0;local pref=self:PreferredRecords();for id in pairs(self.db.characters) do if not pref[id] then dups=dups+1 end end
 if dups>0 then lines[#lines+1]=dups..' duplicate character record'..(dups==1 and '' or 's')..' ignored (the newest copy of each character counts).' end
 lines[#lines+1]='Sync only works while both characters are logged in; nothing is exchanged offline. Export/Import works any time.'
 return table.concat(lines,'\n')
end
-- Plain state of the other character, for the Characters page and diagnostics.
function N:PeerState(peer)
 if self:SyncConnected(peer) then return 'connected, syncing automatically' end
 if not self:PeerMaybeOnline(peer) then return 'offline (friends list); will sync when both are online' end
 local st=type(self.db.sync.status)=='table' and self.db.sync.status[peer]
 if st and st.lastHello and (not st.lastContact or st.lastContact<st.lastHello) and (st.hellos or 0)>=2 then
  return 'not answering: not logged in, other realm/faction, or not paired back'
 end
 return 'waiting for them to log in'
end

N:On('CHAT_MSG_ADDON',function(prefix,msg,channel,sender) N:SyncReceive(prefix,msg,channel,sender) end)
N:On('BAG_UPDATE_DELAYED',function() N:SyncSoon() end)
N:On('BANKFRAME_CLOSED',function() N:SyncSoon() end)
for _,e in ipairs({'MAIL_CLOSED','MAIL_SEND_SUCCESS','MERCHANT_CLOSED','AUCTION_HOUSE_CLOSED','PLAYER_EQUIPMENT_CHANGED'}) do
 N:On(e,function() N:SyncSoon() end)
end
N:On('TRADE_SKILL_CLOSE',function() N:SyncSoon() end)
N:On('CRAFT_CLOSE',function() N:SyncSoon() end)
-- A peer coming online announces itself in the friends list system message;
-- re-hello periodically as a fallback (cheap when hashes match).
N:On('FRIENDLIST_UPDATE',function() N:SyncSoon() end)
-- After a loading screen, retry right away if the other side has not answered.
N:On('PLAYER_ENTERING_WORLD',function()
 for peer in pairs(N.db.sync.peers) do if not N:SyncConnected(peer) and N.syncProbeAt then N.syncProbeAt[peer]=nil end end
end)
