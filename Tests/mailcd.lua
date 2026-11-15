local N,test,eq,widget=...
-- Mail, worn gear and profession cooldowns.

test('Find item covers the mailbox, worn gear and mail you sent that is not collected yet',function()
 local savedChars,savedGII,savedSent=N.db.characters,GetItemInfo,N.db.sentMail
 local names={[2447]='Peacebloom',[2589]='Linen Cloth',[6125]='Brawler\'s Harness',[4306]='Silk Cloth'}
 GetItemInfo=function(id) return names[tonumber(id)] end
 local me=N.character; me.bags={}; me.bank={}; me.mail=nil; me.equipped=nil
 N.db.characters={[N.characterID]=me,
  ['B2/TestRealm/Voidmark Bank']={name='Voidmark Bank',realm='TestRealm',faction='Horde',synced=true,account='B2',at=N:Now(),bags={},bank={[4306]=5},bankAt=N:Now(),mailAt=N:Now()-7200,professions={}}}
 N.db.sentMail={}
 -- Inbox: two mails, one with two attachments.
 local inbox={{true,{{'Peacebloom',2447,nil,20},{'Linen Cloth',2589,nil,10}}},{false,{}},{true,{{'Peacebloom',2447,nil,5}}}}
 GetInboxNumItems=function() return #inbox end
 GetInboxHeaderInfo=function(i) return nil,nil,'Someone','Subject',0,0,30,inbox[i][1] end
 GetInboxItem=function(i,a) local it=inbox[i][2][a]; if it then return it[1],it[2],it[3],it[4] end end
 ATTACHMENTS_MAX_RECEIVE=16
 N:ScanMail(); eq(me.mail[2447],25); eq(me.mail[2589],10); assert(me.mailAt)
 -- Worn gear.
 GetInventoryItemID=function(_,slot) if slot==5 then return 6125 end end
 N:ScanEquipped(); eq(me.equipped[6125],1)
 local item=N:FindItems('peacebloom')[1]; eq(item.total,25)
 assert(N:FinderPlace(item.places[1]):find('mailbox 25',1,true),N:FinderPlace(item.places[1]))
 assert(N:FinderPlace(N:FindItems('harness')[1].places[1]):find('worn',1,true))
 -- Sending 3 Silk Cloth to the bank: it shows in the mail until the bank reads its mailbox.
 GetSendMailItem=function(a) if a==1 then return 'Silk Cloth',4306,nil,3 end end
 ATTACHMENTS_MAX_SEND=12
 N:CaptureOutgoingMail('Voidmark Bank'); N:CommitOutgoingMail()
 local silk=N:FindItems('silk')[1]; eq(silk.total,8)
 local transit; for _,p in ipairs(silk.places) do if p.transit then transit=p end end
 assert(transit and N:FinderPlace(transit):find('In the mail to Voidmark Bank: 3',1,true))
 -- A failed send records nothing.
 N:CaptureOutgoingMail('Voidmark Bank'); N.outgoingMail=nil; N:CommitOutgoingMail(); eq(#N.db.sentMail,1)
 -- The bank opens its mailbox later (synced mailAt newer than the send): the note goes away.
 N.db.characters['B2/TestRealm/Voidmark Bank'].mailAt=N:Now()+5
 eq(N:FindItems('silk')[1].total,5); eq(#N.db.sentMail,0)
 -- Hyphen form of the name matches too.
 N:CaptureOutgoingMail('Voidmark-Bank'); N:CommitOutgoingMail(); N.db.characters['B2/TestRealm/Voidmark Bank'].mailAt=N:Now()+10
 eq(#N:MailInTransit(),0)
 -- Item data still loading: the last good read is kept.
 inbox={{true,{{'Peacebloom',nil,nil,1}}}}; GetInboxItemLink=function() return nil end
 N:ScanMail(); eq(me.mail[2447],25)
 -- Export keeps mail and gear; bad mail is rejected.
 local clean=N:CleanImported(me); eq(clean.mail[2447],25); eq(clean.equipped[6125],1)
 local bad=N:Copy(clean); bad.mail={[2447]=-1}; assert(not pcall(N.ValidateCharacter,N,bad))
 me.mail,me.equipped,me.mailAt=nil,nil,nil
 GetInboxNumItems,GetInboxHeaderInfo,GetInboxItem,GetInventoryItemID,GetSendMailItem,GetInboxItemLink=nil,nil,nil,nil,nil,nil
 N.db.characters,GetItemInfo,N.db.sentMail=savedChars,savedGII,savedSent
end)

test('Cooldowns: read from the game, shown per character, synced, announced when ready',function()
 local savedChars,savedTime=N.db.characters,GetTime
 local me=N.character; me.cooldowns=nil
 GetTime=function() return 1000 end
 local known={Mooncloth=18560,['Transmute: Arcanite']=17187}
 GetSpellInfo=function(name) local id=known[name] or (type(name)=='number' and name); if id then return name,nil,nil,nil,nil,nil,id end end
 GetSpellCooldown=function(id) if id==18560 then return 900,4*86400 elseif id==17187 then return 0,0 end return 0,0 end
 N:ScanCooldowns()
 local moon=me.cooldowns[18560]; assert(moon and moon.name=='Mooncloth')
 eq(moon.readyAt,N:Now()+4*86400-100)
 eq(me.cooldowns[17187].readyAt,N:Now())                       -- ready
 -- A global cooldown is not a profession cooldown.
 GetSpellCooldown=function() return 999,1.5 end; N:ScanCooldowns(); eq(me.cooldowns[18560].readyAt,N:Now())
 GetSpellCooldown=function(id) if id==18560 then return 900,4*86400 end return 0,0 end; N:ScanCooldowns()
 -- Salt Shaker counts only when you carry it.
 GetItemCooldown=function() return 950,3*86400 end
 me.bags={[15846]=1}; N:ScanCooldowns(); assert(me.cooldowns[15846] and me.cooldowns[15846].name=='Salt Shaker'); me.bags={}; N:ScanCooldowns(); eq(me.cooldowns[15846],nil)
 -- Other character's synced cooldowns, and the lists.
 N.db.characters={[N.characterID]=me,['B2/TestRealm/Voidmark Bank']={name='Voidmark Bank',realm='TestRealm',faction='Horde',synced=true,account='B2',at=N:Now(),bags={},bank={},professions={},
  cooldowns={[17187]={name='Transmute: Arcanite',readyAt=N:Now()-60}}}}
 local list=N:CooldownList(); eq(#list,3); eq(list[1].character,'Voidmark Bank'); assert(list[1].ready)
 assert(N:CooldownText(list[#list]):find('Mooncloth in 3d 23h',1,true),N:CooldownText(list[#list]))
 assert(N:CooldownLine():find('Cooldowns: ',1,true))
 local printed={}; local p=N.Print; N.Print=function(_,m) printed[#printed+1]=m end
 N.cooldownsAnnounced=nil; N:AnnounceCooldowns()
 assert(printed[1]:find('Transmute: Arcanite on Voidmark Bank',1,true),printed[1]); N:AnnounceCooldowns(); eq(#printed,1)
 N:CooldownCommand(); eq(#printed,4)
 N.Print=p
 -- Characters page shows the line.
 N:Show('Characters'); N.ui.find:SetText(''); N:Render(); assert(N.ui.syncInfo.text:find('Cooldowns:',1,true))
 -- Validation: bad cooldown rejected; good one exported.
 local clean=N:CleanImported(me); assert(clean.cooldowns[18560])
 local bad=N:Copy(clean); bad.cooldowns={[1]={name='x',readyAt=-5}}; assert(not pcall(N.ValidateCharacter,N,bad))
 me.cooldowns=nil; N.db.characters=savedChars; GetTime=savedTime
 GetSpellInfo,GetSpellCooldown,GetItemCooldown=nil,nil,nil
end)

test('Mail, gear and cooldowns travel with the sync',function()
 local savedPeers=N.db.sync.peers; N.db.sync.peers={['voidmark bank']='Voidmark Bank'}
 local api=C_ChatInfo; C_ChatInfo={SendAddonMessage=function() return 0 end}
 local raw={id=N:EncodeData({name='Voidmark Bank',realm='TestRealm',faction='Horde',guid='GUID-B7',account='B7',at=N:Now()}),
  inv=N:EncodeData({bags={},bank={},bankAt=N:Now(),mail={[2447]=4},mailAt=N:Now(),equipped={[6125]=1},equippedAt=N:Now()}),
  prof=N:EncodeData({professions={},cooldowns={[18560]={name='Mooncloth',readyAt=N:Now()+3600}}})}
 local sender='Voidmark Bank-TestRealm'
 N:SyncReceive('VMNX','H:B7:'..N.SyncHash(raw.id)..':'..N.SyncHash(raw.inv)..':'..N.SyncHash(raw.prof),'WHISPER',sender)
 for _,k in ipairs({'id','inv','prof'}) do N:SyncReceive('VMNX','D:1:'..k..':1:1:'..N.SyncEscape(raw[k]),'WHISPER',sender) end
 local got=assert(N.db.characters['B7/TestRealm/Voidmark Bank'],'stored')
 eq(got.mail[2447],4); eq(got.equipped[6125],1); eq(got.cooldowns[18560].name,'Mooncloth')
 N.db.characters['B7/TestRealm/Voidmark Bank']=nil
 C_ChatInfo=api; N.db.sync.peers=savedPeers; N.syncOut,N.syncContact,N.syncHyphen,N.syncHelloForm,N.syncProbeAt={},nil,nil,nil,nil
end)

test('Find several at once, find all, and /vmn need (have vs shopping list, cost of the rest)',function()
 local me=N.character
 local savedBags,savedNames=me.bags,GetItemInfo
 local names={[4304]='Thick Leather',[4234]='Heavy Leather',[14047]='Runecloth',[2318]='Light Leather'}
 GetItemInfo=function(id) return names[tonumber(id)] end
 me.bags={[4304]=40,[4234]=12,[14047]=600}
 local savedPrice=N.Price;N.Price=function(_,id) return ({[4304]={unit=550},[4234]={unit=220},[2318]={unit=50}})[id] end
 local savedByName=N.ItemIDByName;N.ItemIDByName=function(_,n) for id,x in pairs(names) do if x:lower()==n:lower() then return id end end end
 local printed={};local savedPrint=N.Print;N.Print=function(_,s) printed[#printed+1]=s end
 local ok,err=pcall(function()
  local list=N:FindItems('thick leather, runecloth');eq(#list,2)
  assert(#N:FindItems('all')>=3,'everything')
  N:NeedCommand('100 thick leather, 50 runecloth, 20 light leather')
  local all=table.concat(printed,'\n')
  assert(all:find('Thick Leather: have 40 / need 100',1,true) and all:find('short 60',1,true),all)
  assert(all:find('Runecloth: have 600 / need 50',1,true) and all:find('done',1,true),all)
  assert(all:find('Light Leather: have 0 / need 20',1,true),all)
  assert(all:find('To buy: ~3g 40s 0c',1,true),all) -- 60 x 5s50c + 20 x 50c
  printed={};N:NeedCommand('lw');all=table.concat(printed,'\n')
  assert(all:find('Leatherworking',1,true) and all:find('150-225',1,true) and all:find('Rugged Leather',1,true) and all:find('Runecloth',1,true) and all:find('Total to buy',1,true),all)
 end)
 me.bags=savedBags;GetItemInfo=savedNames;N.Price=savedPrice;N.ItemIDByName=savedByName;N.Print=savedPrint
 assert(ok,err)
end)

test('Reports dropdown: herb report in the window with AH value, and the Alchemy have/need list',function()
 local savedChars,savedGII,savedGIII,savedPrice=N.db.characters,GetItemInfo,GetItemInfoInstant,N.Price
 local names={[2447]='Peacebloom',[765]='Silverleaf',[3820]='Stranglekelp',[2589]='Linen Cloth',[2770]='Copper Ore'}
 GetItemInfo=function(id) return names[tonumber(id)] end
 GetItemInfoInstant=function(id) id=tonumber(id)
  if id==2447 or id==765 or id==3820 then return id,'Trade Goods','Herb','',nil,7,9 end
  if id==2589 then return id,'Trade Goods','Cloth','',nil,7,5 end
  if id==2770 then return id,'Trade Goods','Metal & Stone','',nil,7,7 end end
 N.Price=function(_,id) local t={[2447]=71,[765]=20,[3820]=232};return t[id] and {unit=t[id]} or nil end
 local me=N.character; me.bags={[2447]=30,[2589]=12,[2770]=8}; me.bank={[3820]=40,[765]=5}; me.mail=nil; me.equipped=nil
 N.db.characters={[N.characterID]=me}
 local u=N.ui
 -- Pick "Herb report" from the Reports button.
 if N.menu then N.menu:Hide() end
 u.reports.scripts.OnClick(u.reports)
 local menu=N.menu; assert(menu and menu:IsShown(),'Reports menu opens')
 u.report='herbs'; u.tab='Characters'; N:Render()
 local rows={};for i,b in ipairs(u.rows) do if b:IsShown() and b.data then rows[#rows+1]=b.data.text end end
 assert(rows[1]:find('Total: 75',1,true),'grand total first: '..tostring(rows[1]))
 assert(rows[2]:find('Stranglekelp x40: ',1,true) and rows[2]:find('bank',1,true) and not rows[2]:find('ago',1,true),'one line per item: '..tostring(rows[2]))
 local all=table.concat(rows,'\n')
 assert(all:find('Peacebloom',1,true) and all:find('Silverleaf',1,true),'every herb listed')
 assert(not all:find('Linen',1,true) and not all:find('Copper',1,true),'only herbs')
 assert(u.syncInfo:GetText():find('3 kinds, 75 total',1,true),u.syncInfo:GetText())
 -- Ore report uses the class too; cloth stays out.
 u.report='ore'; N:Render(); assert(u.rows[2].data.text:find('Copper Ore',1,true))
 -- Alchemy have/need list.
 u.report='need:alch'; N:Render()
 local text={};for i,b in ipairs(u.rows) do if b:IsShown() and b.data then text[#text+1]=b.data.text end end
 text=table.concat(text,'\n')
 assert(text:find('1-120',1,true) and text:find('Peacebloom: have 30 / need 81',1,true),text)
 -- Typing in Find closes the report.
 u.find:SetText('peace'); u.find.scripts.OnTextChanged(u.find); eq(u.report,nil)
 u.find:SetText(''); u.find.scripts.OnTextChanged(u.find)
 if N.menu then N.menu:Hide() end
 me.bags,me.bank={}, {}
 N.db.characters,GetItemInfo,GetItemInfoInstant,N.Price=savedChars,savedGII,savedGIII,savedPrice
end)

test('Reports count mail on its way as the recipient\'s',function()
 local out=N:ReportOwners({
  {name='Voidmark Soulreaver',bags=0,bank=10,mail=0,equipped=0},
  {name='In the mail to Voidmark Herbstorage',transit=true,mail=29,bags=0,bank=0,equipped=0},
  {name='Voidmark Herbstorage',bags=5,bank=0,mail=0,equipped=0}})
 eq(out[1],'Herbstorage 34 (bags+mailbox)');eq(out[2],'Soulreaver 10 (bank)')
end)

test('Tooltip counts match Reports: other account alt and mail on its way to it',function()
 local saved,savedSent=N.db.characters,N.db.sentMail
 local me=N.character
 N.db.characters={[N.characterID]=me,
  ['PEER/x/Herbstorage']={name='Voidmark Herbstorage',realm=me.realm,faction=me.faction,imported=true,synced=true,bags={[3356]=5},bank={},professions={}}}
 local mine=me.bags[3356];me.bags[3356]=nil;local mb=me.bank[3356];me.bank[3356]=nil
 local inTransit=N.MailInTransit
 N.MailInTransit=function() return {{to='Voidmark Herbstorage',items={[3356]=60},at=N:Now()}} end
 local total,list=N:ItemCounts(3356);eq(total,65);eq(#list,1)
 local lines={};local tt={AddLine=function(_,s) lines[#lines+1]=s end,AddDoubleLine=function(_,a,b) lines[#lines+1]=a..'='..b end,Show=function() end}
 N:AddItemCounts(tt,3356);eq(lines[1],'Herbstorage=65 (bags+mailbox)')
 N.MailInTransit=inTransit;me.bags[3356]=mine;me.bank[3356]=mb;N.db.characters=saved
end)

test('Sync goes out ~5s after a change, at most every 15s',function()
 local oldT,oldGT,peers=C_Timer,GetTime,N.db.sync.peers
 local delays,now={},1000
 GetTime=function() return now end
 C_Timer=setmetatable({After=function(d,fn) delays[#delays+1]={d=d,fn=fn} end},{__index=oldT})
 N.db.sync.peers={Banky=true};N.syncPending=false;N.syncLastSoon=nil
 N:SyncSoon();eq(delays[1].d,5);delays[1].fn()
 now=1003;N:SyncSoon();eq(delays[2].d,12) -- 15s after the last send
 delays[2].fn()
 N.db.sync.peers,C_Timer,GetTime=peers,oldT,oldGT;N.syncPending=false;N.syncLastSoon=nil
end)

test('Cooking report: an alternative counts toward the need and is priced if cheaper',function()
 local saved,sg,sp=N.db.characters,GetItemInfo,N.Price
 local names={[6303]='Raw Slitherskin Mackerel',[6291]='Raw Brilliant Smallfish'}
 GetItemInfo=function(id) return names[tonumber(id)] end
 N.Price=function(_,id) if id==6303 then return {unit=49} end end
 local me=N.character;local bags=me.bags;me.bags={[6303]=20}
 N.db.characters={[N.characterID]=me}
 local lines,cost=N:NeedLines({{55,'Raw Brilliant Smallfish','Raw Slitherskin Mackerel'}})
 assert(lines[1]:find('or Raw Slitherskin Mackerel: have 20 / need 55',1,true),lines[1])
 eq(cost,35*49)
 me.bags=bags;N.db.characters,GetItemInfo,N.Price=saved,sg,sp
end)

test('Reports work when Forever files materials as plain Trade Goods (subclass 0)',function()
 local saved,sg,si=N.db.characters,GetItemInfo,GetItemInfoInstant
 local names={[2318]='Light Leather',[783]='Light Hide',[4234]='Heavy Leather',[2302]='Handstitched Leather Boots',[2770]='Copper Ore',[2840]='Copper Bar',[2589]='Linen Cloth',[10940]='Strange Dust'}
 GetItemInfo=function(id) return names[tonumber(id)] end
 GetItemInfoInstant=function(id) id=tonumber(id);if id==2302 then return id,'Armor','Leather','',nil,4,2 end;return id,'Trade Goods','Trade Goods','',nil,7,0 end
 local me=N.character;local bags=me.bags;me.bags={[2318]=40,[783]=3,[4234]=5,[2302]=1,[2770]=8,[2840]=2,[2589]=10,[10940]=7}
 N.db.characters={[N.characterID]=me}
 local function kinds(key) local l=N:CategoryList(N.FIND_CATEGORIES[key]);local t={};for _,i in ipairs(l) do t[i.name]=i.total end;return t,#l end
 local lt,ln=kinds('leather');eq(ln,3);eq(lt['Light Leather'],40);eq(lt['Handstitched Leather Boots'],nil)
 local ot,on=kinds('ore');eq(on,2);eq(ot['Copper Bar'],2)
 local ct,cn=kinds('cloth');eq(cn,1)
 local et,en=kinds('enchanting');eq(et['Strange Dust'],7)
 me.bags=bags;N.db.characters,GetItemInfo,GetItemInfoInstant=saved,sg,si
end)

test('Have/need: vendor items are marked vendor, Refined Deeprock Salt priced as Deeprock Salt',function()
 local sg,sp=GetItemInfo,N.Price
 local names={[14341]='Rune Thread',[8150]='Deeprock Salt',[15409]='Refined Deeprock Salt'}
 GetItemInfo=function(id) return names[tonumber(id)] end
 N.Price=function(_,id) local t={[14341]=5500,[8150]=260,[15409]=300000};return t[id] and {unit=t[id]} end
 local savedM=VoidMarkMarketDB
 VoidMarkMarketDB={schemaVersion=1,economies={[(tostring(N.economy):gsub('%s',''))]={market={},itemNames={[8150]='Deeprock Salt',[15409]='Refined Deeprock Salt',[14341]='Rune Thread'}}}}
 local lines,cost=N:NeedLines({{86,'Rune Thread'},{19,'Refined Deeprock Salt'}})
 assert(lines[1]:find('(vendor)',1,true),lines[1])
 assert(lines[2]:find('Salt Shaker from Deeprock Salt',1,true),lines[2])
 eq(cost,19*260)
 VoidMarkMarketDB=savedM
 GetItemInfo,N.Price=sg,sp
end)

test('Reports are item kinds; every profession guide is in the Guides tab',function()
 local keys={};for _,r in ipairs(N.REPORTS) do keys[r.key]=true;assert(N.FIND_CATEGORIES[r.key],'report '..r.key) end
 for _,k in ipairs({'herbs','ore','leather','cloth','enchanting','gems','cooking'}) do assert(keys[k],k) end
 local g={};for _,x in ipairs(N.GUIDE_LIST) do g[x.key]=true end
 for _,k in ipairs({'alch','lw','cook','ench','tail','eng','bs'}) do
  assert(g[k],'guide '..k);assert(N.CRAFT_GUIDES[k] and #N.CRAFT_GUIDES[k].steps>=8,'steps '..k)
  assert(N.NEED_PRESETS[N.CRAFT_GUIDES[k].preset],'preset '..k)
 end
 local lines=N:NeedLines({{96,'Weak Flux'}});assert(lines[1]:find('(vendor)',1,true),'flux is a vendor item')
end)

test('Guides are Horde only: trainers, steps, vendors and materials',function()
 local all={}
 for _,x in ipairs(N.GUIDE_LIST) do
  local rows,info=N:GuideTabRows(x.key);assert(#rows>3,x.key)
  for _,r in ipairs(rows) do all[#all+1]=r.text end;all[#all+1]=info
 end
 all=table.concat(all,'\n')
 for _,bad in ipairs({'Alliance','Ironforge','Stormwind','Darnassus','Theramore','Westfall','Elwynn'}) do assert(not all:find(bad,1,true),bad) end
 local rows,info=N:GuideTabRows('lw');local t={};for _,r in ipairs(rows) do t[#t+1]=r.text end;t=table.concat(t,'\n')
 for _,want in ipairs({'Trainers (Horde)','Karolek - Orgrimmar','Una - Thunder Bluff','Hahrana Ironhide','1-30|r  Light Leather x35','Werg Thickblade','Abigail Shiel','Materials: have / need','Light Leather: have'}) do
  assert(t:find(want,1,true),want)
 end
 assert(info:find('Horde only',1,true))
 rows=N:GuideTabRows('herb');assert(rows[1].text=='Trainers' and rows[2].text:find('Jandi',1,true))
end)

test('Long rows wrap onto extra rows instead of being cut off',function()
 local long={text='   '..('word '):rep(40)..'|cffffd200colored tail goes on and on and on and on and on|r end',color={1,1,1},itemName='X'}
 local out=N:WrapRows({{text='short'},long},396)
 assert(#out>=4,#out);eq(out[1].text,'short')
 for i=2,#out do assert(N:TextWidth(out[i].text)<=396,out[i].text) end
 assert(out[2].text:sub(1,3)=='   ' and out[3].text:sub(1,7)=='       ','continuation indented')
 assert(out[3].noIcon and out[3].itemName=='X')
 local joined={};for i=2,#out do joined[#joined+1]=out[i].text end;joined=table.concat(joined,' ')
 local opens=select(2,joined:gsub('|c',''));local closes=select(2,joined:gsub('|r',''))
 eq(opens,closes)
 -- every word survives
 local words=0;for _ in joined:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gmatch('%S+') do words=words+1 end
 eq(words,40+13)
end)

test('Guides tab: list of guides, then the picked one; long lines wrap',function()
 N:Show('Guides');local u=N.ui
 u.guideKey=nil;N:Render()
 assert(u.rows[1]:IsShown() and u.rows[1].data.text=='Alchemy 1-300',u.rows[1].data.text)
 u.rows[6].data.click();N:Render()
 eq(u.guideKey,'lw');eq(N.db.settings.guide,'lw')
 assert(u.guideInfo:GetText():find('Leatherworking 1-300',1,true))
 for _,b in ipairs(u.rows) do if b:IsShown() then assert(N:TextWidth(b.data.text)<=u.textWidth+1,b.data.text) end end
 N:Show('Lockpicking');N:Show('Guides');u.guideKey='lock';N:Render()
 local any=false;for _,b in ipairs(u.rows) do if b:IsShown() and b.data.text:find('Southsea',1,true) then any=true end end
 assert(any,'lock guide shows')
 u.guideKey=nil;N.db.settings.guide=nil
end)

test('Guides: routes render, camp items show have/need, crates you can fill',function()
 local saved,sg=N.db.characters,GetItemInfo
 local names={[2447]='Peacebloom',[765]='Silverleaf',[2589]='Linen Cloth'}
 GetItemInfo=function(id) return names[tonumber(id)] end
 local me=N.character;local bags=me.bags;me.bags={[2447]=25,[765]=3,[2589]=85}
 N.db.characters={[N.characterID]=me}
 local r=N:GuideRows('herb');assert(#r>10 and r[1].text:find('Peacebloom',1,true))
 for _,k in ipairs({'mine','fish','lock','favor'}) do assert(#N:GuideRows(k)>5,k) end
 local rows,info=N:GuideRows('camp');local all={};for _,x in ipairs(rows) do all[#all+1]=x.text end;all=table.concat(all,'\n')
 assert(all:find('Incense Candle (20): Peacebloom 1/1, Silverleaf 1/1  |cff40ff40can make|r',1,true),all)
 rows,info=N:GuideRows('crates');all={};for _,x in ipairs(rows) do all[#all+1]=x.text end;all=table.concat(all,'\n')
 assert(all:find('Textiles (5 Favor): |cff40ff40can fill 2|r',1,true),all) -- 85 Linen = 2 x 40
 assert(all:find('Herbs (5 Favor): |cff40ff40can fill 1|r',1,true),all) -- 25 Peacebloom = 1 x 20
 local keys={};for _,x in ipairs(N.GUIDE_LIST) do keys[x.key]=true end
 for _,k in ipairs({'camp','crates','favor','herb','mine','fish','lock'}) do assert(keys[k],k) end
 me.bags=bags;N.db.characters,GetItemInfo=saved,sg
end)

test('Guides: pick a character and see where they are (Kitty, Leatherworking 50 of 300)',function()
 local saved,sg=N.db.characters,GetItemInfo
 local names={[783]='Light Hide',[4289]='Salt',[2318]='Light Leather',[2320]='Coarse Thread',[2447]='Peacebloom'}
 GetItemInfo=function(id) return names[tonumber(id)] end
 local me=N.character;local bags,profs,nm=me.bags,me.professions,me.name
 me.name='Kitty';me.bags={[783]=4,[4289]=6,[2318]=100,[2320]=60}
 me.professions={lw={name='Leatherworking',skill=50,max=75,recipes={
  ['1']={name='Cured Light Hide',learned=true,reagents={{id=783,qty=1},{id=4289,qty=1}}},
  ['2']={name='Embossed Leather Gloves',learned=true,reagents={{id=2318,qty=3},{id=2320,qty=2}}},
  ['3']={name='Fine Leather Belt',learned=true,reagents={{id=2318,qty=6},{id=2320,qty=2}}}}}}
 N.db.characters={[N.characterID]=me}
 -- Recipe options are parsed out of the step text.
 local opts,count=N:StepCrafts('Wicked Leather Gauntlets x36 (or Blue Suede Shoes x36)')
 eq(opts[1],'Wicked Leather Gauntlets');eq(opts[2],'Blue Suede Shoes');eq(count,36)
 opts=N:StepCrafts('Brilliant Smallfish, Slitherskin Mackerel, Charred Wolf Meat or Roasted Boar Meat x55');eq(#opts,4);eq(opts[4],'Roasted Boar Meat')
 -- Dropdown lists the character with their skill.
 local list=N:GuideCharacters('lw');eq(list[1].name,'Kitty');eq(list[1].p.skill,50)
 local rows,info,_,frac=N:GuideCharacterRows('lw',N.characterID,false)
 local t={};for _,r in ipairs(rows) do t[#t+1]=r.text end;t=table.concat(t,'\n')
 assert(info:find('Kitty: Leatherworking 50 / 75',1,true) and info:find('step 2 of 18',1,true),info)
 assert(math.abs(frac-50/300)<1e-6)
 assert(t:find('+ 1 step done (1-30)',1,true),t)
 assert(t:find('Train Journeyman (Leatherworking 50, level 10)  |cffffc040train now|r',1,true),t)
 assert(t:find('NOW|r  30-55  Cured Light Hide x27  - about 6 more',1,true),t) -- 27 * 5/25 = 5.4
 assert(t:find('Light Hide: have 4 / need 6',1,true),t)
 assert(t:find('Salt: have 6 / need 6',1,true),t)
 assert(t:find('Kitty 4 (bags)',1,true),t)
 assert(t:find('55-75  Embossed Leather Gloves x21  |cff66dd66mats ready|r',1,true),t) -- 63 leather, 42 thread
 assert(t:find('90-100  Fine Leather Belt x19  |cffffc040short 1 item|r',1,true),t) -- 114 leather > 100
 assert(t:find('Hillman\'s Leather Gloves x17  |cff9a8fb0not learned|r',1,true),t)
 assert(not t:find('1-30  Light Leather x35',1,true),'done steps collapse')
 rows=N:GuideCharacterRows('lw',N.characterID,true)
 t={};for _,r in ipairs(rows) do t[#t+1]=r.text end;t=table.concat(t,'\n')
 assert(t:find('done|r  1-30  Light Leather x35',1,true),'done steps show')
 -- In the window: picking the character shows the view; the current row is marked.
 N:Show('Guides');local u=N.ui;u.guideKey='lw';u.guideChar=N.characterID;u.showDone=false;N:Render()
 assert(u.guideInfo:GetText():find('step 2 of 18',1,true))
 local cur=false;for _,b in ipairs(u.rows) do if b:IsShown() and b.data.current then cur=true end end;assert(cur)
 u.rows[1].data.click();N:Render();assert(u.showDone)
 -- Gathering guide: Herbalism at 120 is on the 115-170 range.
 me.professions={h={name='Herbalism',skill=120,max=150}}
 rows,info=N:GuideCharacterRows('herb',N.characterID,false)
 t={};for _,r in ipairs(rows) do t[#t+1]=r.text end;t=table.concat(t,'\n')
 assert(t:find('NOW|r  115-170: Bruiseweed',1,true),t);assert(t:find('Hillsbrad',1,true))
 -- Not learned.
 rows,info=N:GuideCharacterRows('alch',N.characterID,false);assert(info:find('not learned',1,true))
 u.guideKey=nil;u.guideChar=nil;N.db.settings.guide=nil;N.db.settings.guideChar=nil
 me.bags,me.professions,me.name=bags,profs,nm;N.db.characters,GetItemInfo=saved,sg
end)
