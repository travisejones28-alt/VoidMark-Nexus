local N,test,eq,widget=...
-- 0.11 Priorities 6-8: resizing, filters, sync safety, dashboard, notifications.
local function hold(t) return setmetatable({},{__index=t}) end

test('0.11 window: resizes within bounds, keeps size, and shows rows to fit',function()
 N:Show('Gather')
 local f,u=N.ui.frame,N.ui
 eq(type(f.scripts.OnSizeChanged),'function'); assert(f.grip,'resize grip')
 local w,h=1000,600
 f.GetWidth=function() return w end; f.GetHeight=function() return h end
 N:LayoutUI(); local small=u.perPage
 h=900; f.scripts.OnSizeChanged(); local tall=u.perPage
 assert(tall>small,'taller window shows more rows'); eq(u.width,1000); eq(u.height,900)
 f.grip.scripts.OnMouseUp(); eq(N.db.settings.windowSize[1],1000); eq(N.db.settings.windowSize[2],900)
 local s=N:WindowSize(); eq(s[2],900)
 h=5000; N:LayoutUI(); eq(u.height,1000)               -- clamped
 N.db.settings.windowSize={10,10}; eq(N:WindowSize()[1],480); eq(N.db.settings.windowSize,nil)
 N:Render()
 local shown=0; for _,b in ipairs(u.rows) do if b:IsShown() then shown=shown+1 end end
 assert(shown<=u.perPage)
 N:Slash('resetwindow'); eq(N.db.settings.windowSize,nil); eq(N.db.settings.position,nil)
 f.GetWidth=nil; f.GetHeight=nil; N:LayoutUI(); eq(#N.errors,0)
end)

test('0.13.3 filters: toggle list of every herb and ore; ticks stay open and move the zone',function()
 local s=N.db.settings; local keep={s.kind,s.target,s.routeSelectionMode,s.routeResources,s.routeZone}
 N:Show('Gather')
 local opened
 local choice=N.Choice
 N.Choice=function(self,anchor,options,fn) opened={options=options,fn=fn}; return choice(self,anchor,options,fn) end
 local check=N.Checklist; local list
 N.Checklist=function(self,anchor,items,isChecked,toggle,done,clear) list={items=items,isChecked=isChecked,toggle=toggle,done=done,clear=clear}; return check(self,anchor,items,isChecked,toggle,done,clear) end
 N:ChooseResource(N.ui.what)
 local labels={}; for _,o in ipairs(opened.options) do labels[o.value]=o.label end
 assert(labels['pick:'] and labels['gray:toggle'],'toggle list and grey toggle offered')
 opened.fn('pick:')
 local names={}; for _,o in ipairs(list.items) do if o.value then names[o.value]=true end end
 assert(names["Arthas' Tears"] and names['Peacebloom'] and names['Truesilver Deposit'] and names['Copper Vein'],'every herb and ore listed')
 s.routeZone=nil
 local here=N:ZoneNodes(1411,'herb','')[1]; assert(here)
 list.toggle(here.name); list.toggle("Arthas' Tears")
 assert(list.isChecked(here.name) and list.isChecked("Arthas' Tears"))
 eq(s.routeSelectionMode,'multi'); eq(N:ResourceLabel(),'2 picked')
 for _,n in ipairs(N:ZoneNodes(1411)) do assert(n.name==here.name or n.name=="Arthas' Tears") end
 list.done(); eq(s.routeZone,nil) -- this zone has one of them: stay
 list.toggle(here.name); eq(N:ResourceLabel(),"Only Arthas' Tears")
 list.done()
 if #N:ZoneNodes(1411)==0 and #N:BestZones(1)>0 then assert(s.routeZone and s.routeZone~=1411,'zone moved to where it grows') end
 -- Gather page lists best zones for the pick, best first, clickable.
 list.toggle(here.name); list.toggle("Arthas' Tears"); list.done()
 N.ui.bestZones=nil; local rows=N:RenderGather(N.ui)
 local zrows={}; for _,r in ipairs(rows) do if r.click and r.title then zrows[#zrows+1]=r end end
 local bz=N.ui.bestZones; assert(bz,'best zones computed'); eq(#zrows,#bz)
 for i=2,#bz do assert(bz[i-1].weight>=bz[i].weight,'best first') end
 if zrows[1] then zrows[1].click(); local want=bz[1].map; eq(s.routeZone==nil and 1411 or s.routeZone,want) end
 list.clear(); eq(s.routeResources,nil); eq(s.routeSelectionMode,'all')
 N.Choice=choice; N.Checklist=check
 s.kind,s.target,s.routeSelectionMode,s.routeResources,s.routeZone=keep[1],keep[2],keep[3],keep[4],keep[5]
end)

test('0.11 filters: hiding grey drops resources 100+ below your skill from routes and map',function()
 local c=N.character; c.professions.herbg={name='Herbalism',skill=200,max=225}
 local s=N.db.settings; local keep={s.kind,s.routeSelectionMode}; s.kind,s.routeSelectionMode='herb','herb'
 s.hideGray=false
 local all=N:ZoneNodes(1411)
 s.hideGray=true
 local kept=N:ZoneNodes(1411)
 assert(#kept<#all,'grey herbs hidden'); for _,n in ipairs(kept) do assert(200-(n.skill or 0)<100) end
 N:SelectResource('gray:toggle'); eq(s.hideGray,false)
 c.professions.herbg=nil; s.kind,s.routeSelectionMode=keep[1],keep[2]
end)

-- Sync helpers: deliver one exchange from the bank character.
local function deliver(sections,account)
 local sender='Voidmark-Bank'
 local raw={}; for k,v in pairs(sections) do raw[k]=N:EncodeData(v) end
 local h=function(k) return raw[k] and N.SyncHash(raw[k]) or 'x' end
 N.syncHashes['voidmark bank']=nil
 N:SyncReceive('VMNX','H:'..account..':'..h('id')..':'..h('inv')..':'..h('prof'),'WHISPER',sender)
 for _,k in ipairs({'id','inv','prof'}) do if raw[k] then N:SyncReceive('VMNX','D:'..math.random(1,900)..':'..k..':1:1:'..N.SyncEscape(raw[k]),'WHISPER',sender) end end
end

test('0.11 sync: an older bag, bank or profession snapshot never replaces newer data',function()
 local savedPeers=N.db.sync.peers; N.db.sync.peers={['voidmark bank']='Voidmark Bank'}
 local api=C_ChatInfo; C_ChatInfo={SendAddonMessage=function() return 0 end}
 local t=time()
 local id={name='Voidmark Bank',realm='TestRealm',faction='Horde',guid='GUID-B11',account='B11',at=t}
 deliver({id=id,inv={bags={[2447]=50},bank={[2770]=20},bagsAt=t,bankAt=t},prof={professions={['182']={name='Herbalism',skill=150,max=225,at=t,recipes={}}}}},'B11')
 local key='B11/TestRealm/Voidmark Bank'
 local got=N.db.characters[key]; assert(got); eq(got.bags[2447],50)
 -- A delayed message from an hour earlier arrives afterwards.
 deliver({inv={bags={[2447]=5},bank={[2770]=2},bagsAt=t-3600,bankAt=t-3600},prof={professions={['182']={name='Herbalism',skill=120,max=150,at=t-3600,recipes={}}}}},'B11')
 got=N.db.characters[key]
 eq(got.bags[2447],50); eq(got.bank[2770],20); eq(got.professions['182'].skill,150)
 assert(N.db.sync.status['voidmark bank'].olderRefused>=3)
 -- Newer data still goes through.
 deliver({inv={bags={[2447]=60},bank={[2770]=20},bagsAt=t+10,bankAt=t},prof={professions={['182']={name='Herbalism',skill=151,max=225,at=t+10,recipes={}}}}},'B11')
 got=N.db.characters[key]; eq(got.bags[2447],60); eq(got.professions['182'].skill,151)
 local st=N.db.sync.status['voidmark bank']; assert(st.lastOk and st.lastContact)
 local text=N:SyncStatus()
 assert(text:find('Last successful sync',1,true) and text:find('Older snapshots refused',1,true))
 N.db.characters[key]=nil
 C_ChatInfo=api; N.db.sync.peers=savedPeers; N.syncOut,N.syncContact,N.syncHyphen,N.syncHelloForm,N.syncProbeAt={},nil,nil,nil,nil
end)

test('0.13.13 sync: a peer saved with a blank realm/faction still syncs, warning at most once',function()
 local savedPeers=N.db.sync.peers; N.db.sync.peers={['voidmark bank']='Voidmark Bank'}
 local api=C_ChatInfo; C_ChatInfo={SendAddonMessage=function() return 0 end}
 local t=time(); local me=N.character; N.syncIn['voidmark bank']=nil
 local printed={}; local p=N.Print; N.Print=function(_,s) printed[#printed+1]=s end
 deliver({id={name='Voidmark Bank',realm='',faction='Unknown',guid='GUID-B13',account='B13',at=t},
  inv={bags={[2447]=7},bank={},bagsAt=t,bankAt=t},prof={professions={}}},'B13')
 local got=N.db.characters['B13/'..me.realm..'/Voidmark Bank']
 assert(got,'synced despite blank realm'); eq(got.realm,me.realm); eq(got.faction,me.faction); eq(got.bags[2447],7)
 for _,s in ipairs(printed) do assert(not s:find('Ignored',1,true),s) end
 -- A record that really cannot be used is reported once, not on every message.
 printed={}
 N.syncIn['voidmark bank']=nil
 deliver({id={name='Voidmark Bank',realm='TestRealm',faction='Horde',guid='GUID-B14',account='B14',at=t},
  inv={bags={[2447]=-1},bank={},bagsAt=t,bankAt=t},prof={professions={}}},'B14')
 deliver({inv={bags={[2447]=-2},bank={},bagsAt=t+1,bankAt=t},prof={professions={}}},'B14')
 local n=0; for _,s in ipairs(printed) do if s:find('Ignored sync from Voidmark Bank',1,true) then n=n+1 end end
 eq(n,1)
 -- Missing identity fields are named.
 local ok,err=pcall(N.ValidateCharacter,N,{name='A',realm='',faction='Horde',account='x'})
 assert(not ok and tostring(err):find('realm missing',1,true),tostring(err))
 N.Print=p; N.db.characters['B13/'..me.realm..'/Voidmark Bank']=nil; N.db.characters['B14/TestRealm/Voidmark Bank']=nil; N.syncWarned=nil
 C_ChatInfo=api; N.db.sync.peers=savedPeers; N.syncOut,N.syncContact,N.syncHyphen,N.syncHelloForm,N.syncProbeAt={},nil,nil,nil,nil
 N.syncIn['voidmark bank']=nil; N.syncHashes['voidmark bank']=nil
end)

test('0.13.14 identity: realm key never flips between spaced and unspaced; stale synced copies pruned',function()
 local add={['X/Test Realm/Voidmark Bank']={name='Voidmark Bank',realm='Test Realm',faction='Horde',account='X',imported=true,synced=true,at=time()-100,bags={},bank={},professions={}},
  ['X/TestRealm/Voidmark Bank']={name='Voidmark Bank',realm='TestRealm',faction='Horde',account='X',imported=true,synced=true,at=time(),bags={},bank={},professions={}}}
 for k,v in pairs(add) do N.db.characters[k]=v end
 eq(N:PruneSyncedCopies(),1)
 eq(N.db.characters['X/Test Realm/Voidmark Bank'],nil); assert(N.db.characters['X/TestRealm/Voidmark Bank'])
 assert(N.db.characters[N.characterID],'own record kept')
 N.db.characters['X/TestRealm/Voidmark Bank']=nil
 eq(('Test Realm'):gsub('%s',''),'TestRealm')
end)

test('0.13.17 records filed under Unknown move to the real realm; newer copy wins; prices merged',function()
 local d=N.db; local t=time()
 d.characters['B17/Unknown/Voidmark Bank']={name='Voidmark Bank',realm='Unknown',faction='Horde',account='B17',imported=true,synced=true,at=t,bags={[1]=2},bank={},professions={}}
 d.characters['B17/TestRealm/Voidmark Bank']={name='Voidmark Bank',realm='TestRealm',faction='Horde',account='B17',imported=true,synced=true,at=t-500,bags={[1]=1},bank={},professions={}}
 d.prices['Unknown|Horde']={[424242]={manual={unit=5,at=t}}}
 N:RehomeUnknown(d,'TestRealm')
 eq(d.characters['B17/Unknown/Voidmark Bank'],nil); eq(d.characters['B17/TestRealm/Voidmark Bank'].bags[1],2)
 eq(d.prices['Unknown|Horde'],nil); eq(d.prices['TestRealm|Horde'][424242].manual.unit,5)
 d.characters['B17/TestRealm/Voidmark Bank']=nil; d.prices['TestRealm|Horde'][424242]=nil
end)

test('0.13.17 prices come from Market itself (bank-synced prices included)',function()
 local old=VoidMarkMarket; local now=time()
 VoidMarkMarket={db={},PriceObservation=function(_,id) if id==3575 then return {floor=278,fair=290,at=now-60,source='Synced account',confidence=80} end end}
 N.prices[3575]=nil
 local p=N:Price(3575); assert(p,'no price'); eq(p.unit,290); eq(p.source,'VoidMark Market (synced)')
 VoidMarkMarket=old; N.prices[3575]=nil
end)

test('0.13.15 identity: realm unknown at load is moved to the real realm at login',function()
 local id0,c=N.characterID,N.character; local realm0=c.realm
 local unk=N.db.account..'/Unknown/'..c.name
 N.db.characters[id0]=nil; N.db.characters[unk]=c; c.realm='Unknown'; N.characterID=unk
 N:RefreshIdentity()
 eq(N.characterID,id0); eq(c.realm,realm0); eq(N.db.characters[unk],nil); assert(N.db.characters[id0]==c)
end)

test('0.13.13 identity: an empty realm name at load falls back instead of being saved blank',function()
 local g=GetNormalizedRealmName
 GetNormalizedRealmName=function() return '' end
 local given=function(v) v=N:Text(v); return v and v~='' and v or nil end
 eq(given(N:Call(GetNormalizedRealmName)) or given(N:Call(GetRealmName)) or 'Unknown','Test Realm')
 GetNormalizedRealmName=g
 local c=N.character; local f,e=c.faction,N.economy; c.faction='Unknown'; N:RefreshIdentity(); eq(c.faction,'Horde')
 c.faction=f; N.economy=e; N.prices=N.db.prices[e]
end)

test('0.11 sync: status says plainly when the other account is unavailable or stale',function()
 local savedPeers,savedStatus=N.db.sync.peers,N.db.sync.status
 N.db.sync.peers={['voidmark bank']='Voidmark Bank'}; N.db.sync.status={}
 N.syncContact={}
 C_FriendList={GetFriendInfo=function() return {connected=false} end}
 assert(N:PeerState('voidmark bank'):find('offline',1,true))
 C_FriendList=nil
 N.db.sync.status['voidmark bank']={lastHello=time(),hellos=3}
 assert(N:PeerState('voidmark bank'):find('not answering',1,true))
 local key='B12/TestRealm/Voidmark Bank'
 N.db.characters[key]={name='Voidmark Bank',realm='TestRealm',faction='Horde',guid='G-12',synced=true,imported=true,syncedAt=time()-90000,
  bagsAt=time()-30*86400,bankAt=time()-30*86400,bags={},bank={},professions={}}
 assert(N:SyncStatus():find('STALE',1,true))
 N:Show('Characters'); N:Render()
 assert(N.ui.syncInfo.text:find('not answering',1,true))
 N.db.characters[key]=nil; N.db.sync.peers=savedPeers; N.db.sync.status=savedStatus
end)

test('0.11 transfers: queued crafts list what to mail from which character',function()
 local savedPlans=N.db.plans
 local me=N.character
 me.professions.tr11={name='Alchemy',skill=50,max=150,recipes={x={name='Thing',learned=true,reagents={{id=2447,qty=4}},difficulty='optimal'}}}
 me.bags={}; me.bagsAt=time()
 local key='B13/'..me.realm..'/Voidmark Bank'
 N.db.characters[key]={name='Voidmark Bank',realm=me.realm,faction=me.faction,guid='G-13',account='B13',synced=true,imported=true,syncedAt=time(),
  bags={[2447]=10},bank={},bagsAt=time(),bankAt=time(),professions={}}
 N.db.plans={{character=N.characterID,profession='tr11',recipe='x',qty=2}}
 local text=N:TransferPlanText()
 assert(text:find('Voidmark Bank',1,true) and text:find('8 x',1,true),text)
 N.db.characters[key]=nil; me.professions.tr11=nil; N.db.plans=savedPlans
end)

test('0.11 dashboard: session figures, comparison with past sessions, window toggles',function()
 N:StartSession()
 local s=N.session; s.started=time()-1800
 s.items={[2447]=10,[999999]=2}; s.total=12; s.nodes=6
 N.db.settings.market=false; N:SetPrice(2447,.5)
 local st=N:DashboardStats(); eq(st.unpriced,2); assert(st.gold and st.gold>0); eq(math.floor(st.nodesPerHour+.5),12)
 N.db.sessions[#N.db.sessions+1]={started=time()-7200,finished=time()-3600,items={[2447]=20},total=20}
 local prev=N:PreviousSessionAverages(); assert(prev and prev.count>=1)
 local lines=N:DashboardLines(); assert(#lines>=3); assert(lines[3]:find('unpriced',1,true))
 N:Slash('dash'); assert(N.dashboard:IsShown()); assert(N.dashboard.text.text:find('Session',1,true))
 N:Slash('dash'); assert(not N.dashboard:IsShown())
 N.db.settings.market=true
end)

test('0.11 notifications: near and at rank cap once each; never with notify off',function()
 local me=N.character; N.db.notified={}
 local said={}; local print=N.Print; N.Print=function(_,t) said[#said+1]=t end
 me.professions.cap11={name='Mining',skill=72,max=75}
 N:CheckRankCaps(); N:CheckRankCaps(); eq(#said,1); assert(said[1]:find('3 points',1,true))
 me.professions.cap11.skill=75; N:CheckRankCaps(); eq(#said,2); assert(said[2]:find('rank cap reached',1,true))
 me.professions.cap11={name='Mining',skill=145,max=150}; N.db.settings.notify=false; N:CheckRankCaps(); eq(#said,2)
 N.db.settings.notify=true; me.professions.cap11=nil; N.Print=print
end)

test('0.11 API: other addons get read-only copies of gathering figures',function()
 eq(N.API.version,1)
 local st=N.API.GetSessionStats(); assert(st); st.total=-1; assert(N:DashboardStats().total~=-1)
 assert(type(N.API.GetBestRoutes(3))=='table')
end)
