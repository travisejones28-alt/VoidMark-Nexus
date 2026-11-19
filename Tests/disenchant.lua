-- Disenchant module regression tests (Lua 5.1).
local N,test,eq,widget=...
local function close(a,b) assert(math.abs(a-b)<0.001,tostring(a)..' ~= '..tostring(b)) end

test('DE built-in Forever fallback uses actual item level, distinct green weapons and armor',function()
 local a=N:DEBaseline(2,25,4);eq(#a,3);eq(a[1].itemId,10940);eq(a[2].itemId,10998)
 eq(a[1].probability,75);eq(a[2].probability,15);eq(a[3].probability,10)
 local w=N:DEBaseline(2,25,2);eq(w[1].probability,15);eq(w[2].probability,75)
 eq(N:DEBaseline(2,66,4),nil);eq(N:DEBaseline(3,90,2),nil)
 eq(N:DEBaseline(4,80,2),nil)
end)
test('DE blue and purple brackets stay in vanilla, never return prismatic or void',function()
 eq(N:DEBaseline(3,50,2)[1].itemId,11178)
 eq(N:DEBaseline(3,65,2)[1].itemId,14344)
 eq(N:DEBaseline(4,60,4)[1].itemId,20725)
 eq(N:DEBaseline(4,60,4)[1].maxQuantity,1)
 eq(N:DEBaseline(4,39,4),nil)
end)
test('DE external API validates probability, quantity and classic materials',function()
 assert(N:DEValidate({{itemId=20725,probability=33,minQuantity=1,maxQuantity=1},
  {itemId=20725,probability=67,minQuantity=2,maxQuantity=2}}))
 eq(N:DEValidate({{itemId=20725,probability=50,minQuantity=1,maxQuantity=2}}),nil)
 eq(N:DEValidate({{itemId=22445,probability=100,minQuantity=1,maxQuantity=1}}),nil)
 eq(N:DEValidate({{itemId=20725,probability=100,minQuantity=2,maxQuantity=1}}),nil)
end)
-- Isolate actual API item metadata, data sources and price settings.
local oldInfo,oldBuddy=GetItemInfo,DisenchantBuddy
local old={manualFirst=N.db.settings.manualFirst,market=N.db.settings.market,
 auctionator=N.db.settings.auctionator,cut=N.db.settings.cut,
 saleFraction=N.db.settings.saleFraction,deTooltips=N.db.settings.deTooltips}
local ids={16204,16203,14344,20725,777001,777002}
local saved={}
for _,id in ipairs(ids) do saved[id]=N.prices[id] end
local quality,ilevel,klass,vendor=2,60,4,1000
GetItemInfo=function(id)
 if type(id)=='string' then id=tonumber(id:match('item:(%d+)')) or tonumber(id) end
 return 'Test DE Gear','item:'..tostring(id),quality,ilevel,1,'Armor','Plate',1,'INVTYPE_HEAD','icon',vendor,klass
end
N.db.settings.manualFirst=true;N.db.settings.market=false;N.db.settings.auctionator=false
N.db.settings.cut=.05;N.db.settings.saleFraction=1
N:SetPrice(16204,.2);N:SetPrice(16203,.3);N:SetPrice(14344,.1)
N:SetPrice(20725,.15);N:SetPrice(777001,.1);N:SetPrice(777002,.1)

test('DE exact weighted average, after-sale fee, and best of three options',function()
 local v=N:DEValue('item:777001');assert(v)
 close(v.gross,1.125*2000+.3*3000+.05*1000)
 close(v.net,v.gross*.95);eq(v.vendor,1000);eq(v.auctionNet,950)
 eq(v.best,'Disenchant');eq(v.unknownPrices,0)
 eq(v.source,'Classic-based Forever estimate (unverified)')
end)
test('DE never prices a material with no market data as zero',function()
 local oldPrice=N.prices[14344];N.prices[14344]=nil
 local v=N:DEValue(777001);eq(v.net,nil);eq(v.best,nil);eq(v.unknownPrices,1)
 N.prices[14344]=oldPrice
end)
test('DE blocks unsupported high-level rares even with another addon installed',function()
 quality=3;ilevel=90
 DisenchantBuddy={API={v1={GetDisenchantResults=function() return {
  {itemId=20725,probability=100,minQuantity=1,maxQuantity=1}} end}}}
 local v,err=N:DEValue(777002);eq(v,nil);assert(err:find('No confirmed Forever',1,true))
 quality=2;ilevel=60
end)
test('DE supported external API odds preserve duplicate material outcome entries',function()
 quality=4;ilevel=80
 DisenchantBuddy={API={v1={GetDisenchantResults=function() return {
  {itemId=20725,probability=33,minQuantity=1,maxQuantity=1},
  {itemId=20725,probability=67,minQuantity=2,maxQuantity=2}} end}}}
 local v=N:DEValue(777001);assert(v)
 eq(v.source,'DisenchantBuddy API (external estimate)')
 close(v.rows[1].expected+v.rows[2].expected,1.67)
 close(v.gross,1.67*1500)
 DisenchantBuddy=nil;quality=2;ilevel=60
end)
test('DE command, tooltip dedupe and user toggle',function()
 local captured,p={},N.Print
 N.Print=function(_,s) captured[#captured+1]=s end
 N:DECommand('777001')
 assert(#captured>=4);assert(captured[#captured]:find('not guaranteed',1,true))
 N:DECommand('off');eq(N.db.settings.deTooltips,false)
 N:DECommand('on');eq(N.db.settings.deTooltips,true)
 local tt={lines={},AddDoubleLine=function(self,a,b) self.lines[#self.lines+1]=a..b end,
  AddLine=function(self,s) self.lines[#self.lines+1]=s end,Show=function() end}
 N:AddDisenchantTooltip(tt,777001);assert(#tt.lines>=3)
 local n=#tt.lines;N:AddDisenchantTooltip(tt,777001);eq(#tt.lines,n)
 N.Print=p
end)
test('0.13.11 DE: not-in-latest-scan prices still give a best option; only old or untrusted ones are flagged',function()
 local realPrice=N.Price
 local function tip() local tt={lines={},AddDoubleLine=function(self,a,b) self.lines[#self.lines+1]=a..b end,
  AddLine=function(self,s) self.lines[#self.lines+1]=s end,Show=function() end}; N:AddDisenchantTooltip(tt,777001); return table.concat(tt.lines,'\n') end
 -- Market "stale" status (seen today, just not in the very last scan).
 N.Price=function(self,id) local p=realPrice(self,id); if p then p.stale=true; p.marketStatus='stale'; p.at=N:Now()-3600 end; return p end
 local v=N:DEValue(777001); eq(v.best,'Disenchant'); eq(v.stale,false)
 local t=tip(); assert(t:find('Best estimate: Disenchant',1,true),t); assert(not t:find('stale',1,true)); assert(not t:find('verify eligibility',1,true))
 -- Last seen two days ago: still a best option, marked as old.
 N.Price=function(self,id) local p=realPrice(self,id); if p then p.at=N:Now()-2*86400 end; return p end
 v=N:DEValue(777001); eq(v.best,'Disenchant'); eq(v.stale,true)
 assert(tip():find('over a day old',1,true))
 -- Untrusted Market data: no best option.
 N.Price=function(self,id) local p=realPrice(self,id); if p then p.untrusted=true end; return p end
 v=N:DEValue(777001); eq(v.best,nil); assert(tip():find('not trusted',1,true))
 N.Price=realPrice
end)
GetItemInfo=oldInfo;DisenchantBuddy=oldBuddy
for k,v in pairs(old) do N.db.settings[k]=v end
for _,id in ipairs(ids) do N.prices[id]=saved[id] end
