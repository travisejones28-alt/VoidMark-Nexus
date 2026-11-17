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

test('0.13.2 filters: One herb / One ore list every resource in the game and move the zone',function()
 local s=N.db.settings; local keep={s.kind,s.target,s.routeSelectionMode,s.routeResources,s.routeZone}
 N:Show('Gather')
 local opened
 local choice=N.Choice
 N.Choice=function(self,anchor,options,fn) opened={options=options,fn=fn}; return choice(self,anchor,options,fn) end
 N:ChooseResource(N.ui.what)
 local labels={}; for _,o in ipairs(opened.options) do labels[o.value]=o.label end
 assert(labels['list:herb'] and labels['list:ore'] and labels['gray:toggle'],'one herb / one ore and grey toggle offered')
 assert(not labels['multi:'],'pick several removed')
 opened.fn('list:herb')
 local herbs={}; for _,o in ipairs(opened.options) do herbs[o.value]=o.label end
 assert(herbs["name:Arthas' Tears"],'Arthas Tears listed even outside its zones')
 assert(herbs['name:Peacebloom'] and herbs['name:Black Lotus'],'all herbs listed')
 for v in pairs(herbs) do assert(v=='back' or not v:find('Vein',1,true),'no ore in herb list') end
 opened.fn('back'); assert(labels['list:ore'])
 opened.fn('list:ore')
 local ores={}; for _,o in ipairs(opened.options) do ores[o.value]=true end
 assert(ores['name:Truesilver Deposit'] and ores['name:Copper Vein'],'all ore listed')
 s.routeZone=nil
 local here=N:ZoneNodes(1411,'herb','')[1]
 assert(here,'test zone has herbs')
 opened.fn('name:'..here.name)
 eq(s.routeSelectionMode,'name'); eq(N:ResourceLabel(),'Only '..here.name); eq(s.routeZone,nil)
 N:SelectResource("name:Arthas' Tears")
 if #N:ZoneNodes(1411,'herb',"Arthas' Tears")==0 and #N:BestZones(1)>0 then assert(s.routeZone and s.routeZone~=1411,'zone moved to where it grows') end
 N.Choice=choice
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
