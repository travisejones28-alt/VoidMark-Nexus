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
  assert(all:find('Leatherworking',1,true) and all:find('150-225',1,true) and all:find('Rugged Leather',1,true) and all:find('Total to buy',1,true),all)
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
