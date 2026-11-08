-- 0.4.1: live sync, recorded trainers/vendors, resizable window.
local N,test,eq,widget=...

local sent={}
C_ChatInfo={SendAddonMessage=function(prefix,msg,channel,target) sent[#sent+1]={prefix=prefix,msg=msg,channel=channel,target=target} end,
 RegisterAddonMessagePrefix=function() return true end}

local function sections(record)
 local s={}
 s.id=N:EncodeData({name=record.name,realm=record.realm,faction=record.faction,account=record.account,at=record.at})
 s.inv=N:EncodeData({bags=record.bags,bank=record.bank,bagsAt=record.bagsAt,bankAt=record.bankAt})
 s.prof=N:EncodeData({professions=record.professions})
 return s
end
local function deliver(sender,key,raw,seq)
 raw=N.SyncEscape(raw)
 local n=math.ceil(#raw/230)
 for i=n,1,-1 do -- out of order on purpose
  N:SyncReceive('VMNX',string.format('D:%d:%s:%d:%d:',seq,key,i,n)..raw:sub((i-1)*230+1,i*230),'WHISPER',sender)
 end
end

test('Sync escaping round-trips newlines, tildes and NUL bytes',function()
 local raw='a~b\nc\rd\0e~~'
 eq(N.SyncUnescape(N.SyncEscape(raw)),raw)
 assert(not N.SyncEscape(raw):find('[\n\r%z]'))
end)

test('Paired live sync applies a peer account character and counts its bank',function()
 N.db.sync.peers={};N.db.sync.known={};N.syncIn,N.syncHashes,N.syncOut={},N.db.sync.known,{}
 N:PairPeer('Banky-TestRealm');assert(N.db.sync.peers.banky)
 N:FlushSync()
 local hello=sent[#sent];eq(hello.target,'Banky');assert(hello.msg:find('^H:'));eq(hello.channel,'WHISPER')
 local now=N:Now()
 local peer={name='Banky',realm='TestRealm',faction='Horde',account='PEER-1',at=now,bags={[2770]=40},bagsAt=now,bank={[2771]=7},bankAt=now,
  professions={tailoring={name='Tailoring',skill=50,max=75,at=now,recipes={bolt={name='Bolt of Linen\nCloth',learned=true,reagents={{id=2589,qty=2}},outputMin=1,outputMax=1,at=now}}}}}
 local s=sections(peer)
 sent={}
 local H=function(x) return N.SyncHash(x) end
 N:SyncReceive('VMNX','H:PEER-1:'..H(s.id)..':'..H(s.inv)..':'..H(s.prof),'WHISPER','Banky')
 N:FlushSync()
 local q,r
 for _,m in ipairs(sent) do if m.msg:find('^Q:') then q=m.msg elseif m.msg:find('^R:') then r=m.msg end end
 eq(q,'Q:id,inv,prof');assert(r,'reply with our hashes')
 deliver('Banky','id',s.id,1);deliver('Banky','inv',s.inv,2);deliver('Banky','prof',s.prof,3)
 local c=N.db.characters['PEER-1/TestRealm/Banky']
 assert(c and c.synced and c.imported);eq(c.bank[2771],7)
 eq(c.professions.tailoring.recipes.bolt.name,'Bolt of Linen\nCloth')
 local stock=N:Stock(N.characterID)
 local found
 for _,row in ipairs(stock[2771] or {}) do if row.id=='PEER-1/TestRealm/Banky' then found=row end end
 assert(found,'synced bank counts as inventory');assert(found.transfer:find('other account',1,true))
 N.db.settings.includeSynced=false;N.renderStocks=nil
 eq(N:Stock(N.characterID)[2771],nil);N.db.settings.includeSynced=true
 -- Unchanged hashes are not requested again.
 sent={};N:SyncReceive('VMNX','R:PEER-1:'..H(s.id)..':'..H(s.inv)..':'..H(s.prof),'WHISPER','Banky');N:FlushSync();eq(#sent,0)
 -- After a reload, an inventory-only update still applies to the stored record.
 peer.bags={[2770]=1};local s2=sections(peer)
 N.syncIn={};N.syncHashes.banky={account='PEER-1',id=H(s.id),prof=H(s.prof)}
 sent={};N:SyncReceive('VMNX','H:PEER-1:'..H(s.id)..':'..H(s2.inv)..':'..H(s.prof),'WHISPER','Banky');N:FlushSync()
 local asked;for _,m in ipairs(sent) do if m.msg:find('^Q:') then asked=m.msg end end;eq(asked,'Q:inv')
 deliver('Banky','inv',s2.inv,9)
 eq(N.db.characters['PEER-1/TestRealm/Banky'].bags[2770],1)
 eq(N.db.characters['PEER-1/TestRealm/Banky'].professions.tailoring.skill,50)
end)

test('Sync ignores unpaired senders, own account and mismatched names',function()
 local before=0;for _ in pairs(N.db.characters) do before=before+1 end
 N:SyncReceive('VMNX','H:EVIL-1:a:b:c','WHISPER','Stranger')
 eq(N.syncIn.stranger,nil)
 N:SyncReceive('VMNX','H:'..N.db.account..':a:b:c','WHISPER','Banky')
 N.syncIn.banky={account='PEER-2'}
 local s=sections({name='Someoneelse',realm='TestRealm',faction='Horde',account='PEER-2',at=N:Now(),bags={},bank={},professions={}})
 deliver('Banky','id',s.id,4)
 local after=0;for _ in pairs(N.db.characters) do after=after+1 end
 eq(after,before)
 N:UnpairPeer('Banky');eq(N.db.sync.peers.banky,nil)
end)

test('Trainer and recipe-vendor windows are recorded and used by the planner',function()
 local oldUnit=UnitName
 UnitName=function(unit) if unit=='npc' then return 'Test Trainer' end return oldUnit(unit) end
 IsTradeskillTrainer=function() return true end
 GetNumTrainerServices=function() return 3 end
 local services={{'Plancraft','',  'header'},{'Elixir of Testing','','available'},{'Expert Plancraft','','unavailable'}}
 GetTrainerServiceInfo=function(i) return unpack(services[i]) end
 GetTrainerServiceSkillReq=function(i) if i==2 then return 'Plancraft',120,true end if i==3 then return 'Plancraft',125,false end end
 GetTrainerServiceCost=function(i) return i*1000 end
 GetTrainerServiceLevelReq=function() return 10 end
 N.db.trainers={};N:ScanTrainer()
 local t=N.db.trainers.Plancraft;assert(t,'trainer recorded under its profession')
 local entry=select(2,next(t));eq(entry.name,'Test Trainer');eq(entry.services['Elixir of Testing'].skill,120);eq(entry.services['Elixir of Testing'].cost,2000)
 local list=N:TrainableRecipes('Plancraft',{},150);eq(#list,1);eq(list[1].name,'Elixir of Testing')
 eq(#N:TrainableRecipes('Plancraft',{['Elixir of Testing']=true},150),0)
 UnitName=function(unit) if unit=='npc' then return 'Recipe Seller' end return oldUnit(unit) end
 GetMerchantNumItems=function() return 2 end
 GetMerchantItemInfo=function(i) if i==1 then return 'Recipe: Locked Thing','tex',2000,1,1 end return 'Light Feather','tex',10,1,-1 end
 GetMerchantItemLink=function(i) return i==1 and '|Hitem:9001|h[Recipe: Locked Thing]|h' or '|Hitem:17056|h[Light Feather]|h' end
 N.db.recipeVendors={};N:ScanMerchant()
 eq(N.db.recipeVendors[9001].recipe,'Locked Thing');eq(N.db.recipeVendors[17056],nil)
 local src=N:RecipeSources('Plancraft','Locked Thing');eq(#src,1);eq(src[1].kind,'vendor');eq(src[1].cost,2000)
 -- Planner shows where to get the unlearned recipe and what to train.
 N.db.levelEvidence={}
 local p={name='Plancraft',skill=100,max=150,at=N:Now(),recipes={
  a={name='Cheap Thing',learned=true,difficulty='optimal',reagents={{id=501,qty=1}}},
  c={name='Locked Thing',learned=false,difficulty='optimal',reagents={{id=503,qty=1}}}}}
 N.character.professions.Plancraft=p
 N:SetPrice(501,.01)
 local plan=N:LevelingPlan(N.characterID,'Plancraft',120,'Cheapest')
 local summary=N:LevelingSummary(plan)
 assert(summary:find('Vendor Recipe Seller',1,true),'vendor source in plan')
 assert(summary:find('Elixir of Testing at skill 120',1,true),'trainable recipe in plan')
 N.character.professions.Plancraft=nil
 UnitName=oldUnit;IsTradeskillTrainer=nil;GetNumTrainerServices=nil;GetMerchantNumItems=nil
end)

test('Window layout follows its size and pages by visible rows',function()
 N:Show('Recipes');N:LayoutUI()
 eq(N.ui.perPage,math.floor((600-212)/28))
 assert(not N.ui.rows[N.ui.perPage+1]:IsShown())
 N:Render()
 assert(N.ui.pageLabel.text:find('/',1,true))
end)
