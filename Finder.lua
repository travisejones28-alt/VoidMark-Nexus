local _,N=...
-- Find an item anywhere: every saved character's bags and bank (this account,
-- the synced bank account and imports). Type part of a name, an item ID, or
-- shift-click an item into the box.

local requested={}

-- Best known name: the live client cache, then names saved from earlier scans,
-- then VoidMark Market's scanned names. Unknown items are requested once.
function N:FinderName(id)
 local name=self:Text(self:Call(GetItemInfo,id))
 if name and name~='' then
  if self.db.itemNames[id]~=name then self.db.itemNames[id]=name end
  return name
 end
 name=self.db.itemNames[id]
 if type(name)=='string' and name~='' then return name end
 local m=VoidMarkMarketDB
 m=type(m)=='table' and type(m.economies)=='table' and m.economies[self.economy]
 m=type(m)=='table' and type(m.market)=='table' and (m.market[id] or m.market[tostring(id)])
 if type(m)=='table' and type(m.name)=='string' and m.name~='' and not m.name:find('^Item %d') then
  self.db.itemNames[id]=m.name; return m.name
 end
 if not requested[id] then
  requested[id]=true
  if C_Item and C_Item.RequestLoadItemDataByID then self:Call(C_Item.RequestLoadItemDataByID,id) end
 end
 return nil
end

local function words(query)
 local out={}
 for w in query:lower():gmatch('%S+') do out[#out+1]=w end
 return out
end
-- ws: one or more word groups ("thick leather, runecloth" = either).
-- An empty group list ("all", "*") matches everything.
local function matches(name,groups)
 if #groups==0 then return true end
 local l=name:lower()
 for _,ws in ipairs(groups) do
  local ok=true
  for _,w in ipairs(ws) do if not l:find(w,1,true) then ok=false;break end end
  if ok then return true end
 end
 return false
end

-- Category words for Find: "herbs", "ore", "leather", "cloth", "enchanting".
-- Trade Goods subclasses, plus known names in case the client reports another.
N.FIND_CATEGORIES={
 herbs={label='Herbs',class=7,sub=9,names={'peacebloom','silverleaf','earthroot','mageroyal','briarthorn','swiftthistle','stranglekelp','bruiseweed','wild steelbloom','grave moss','kingsblood','liferoot','fadeleaf','goldthorn',"khadgar's whisker",'wintersbite','firebloom','purple lotus',"arthas' tears",'sungrass','blindweed','ghost mushroom','gromsblood','golden sansam','dreamfoil','mountain silversage','plaguebloom','icecap','black lotus'}},
 ore={label='Ore, bars and stone',class=7,sub=7},
 leather={label='Leather and hides',class=7,sub=6},
 cloth={label='Cloth',class=7,sub=5},
 enchanting={label='Enchanting materials',class=7,sub=12},
}
for word,c in pairs(N.FIND_CATEGORIES) do c.word=word end
local CATEGORY_WORDS={herb='herbs',herbs='herbs',ore='ore',ores='ore',mining='ore',leather='leather',hides='leather',skins='leather',
 cloth='cloth',enchanting='enchanting',enchant='enchanting',dust='enchanting'}
function N:FindCategory(query)
 return self.FIND_CATEGORIES[CATEGORY_WORDS[tostring(query or ''):lower():match('^%s*(.-)%s*$')] or '']
end
function N:InCategory(id,cat,name)
 if type(GetItemInfoInstant)=='function' then
  local ok,_,_,_,_,_,class,sub=pcall(GetItemInfoInstant,id)
  if ok and class==cat.class and sub==cat.sub then return true end
 end
 local l=type(name)=='string' and name:lower()
 if l and cat.names then for _,n in ipairs(cat.names) do if l==n then return true end end end
 return false
end

-- Returns items sorted by total held, each with every place it is stored.
function N:FindItems(query)
 query=type(query)=='string' and query:match('^%s*(.-)%s*$') or ''
 if query=='' then return {},0 end
 local wantID=tonumber(query:match('item:(%d+)') or query:match('^#?(%d+)$'))
 local label=query:match('|h%[(.-)%]|h'); if label then query=label end
 local ws={}
 local everything=query:lower()=='all' or query=='*'
 if not everything then
  for part in (query..','):gmatch('([^,]*),') do local w=words(part);if #w>0 then ws[#ws+1]=w end end
 end
 local cat=self:FindCategory(query)
 local byItem,unnamed={},{}
 local function lookup(id)
  local item=byItem[id]
  if item==nil then
   local name=self:FinderName(id)
   if wantID then item=(id==wantID) and {id=id,name=name or ('Item '..id),total=0,places={},at={}} or false
   elseif cat then item=self:InCategory(id,cat,name) and {id=id,name=name or ('Item '..id),total=0,places={},at={}} or false
   elseif name then item=matches(name,ws) and {id=id,name=name,total=0,places={},at={}} or false
   else unnamed[id]=true; item=false end
   byItem[id]=item
  end
  return item
 end
 local preferred=self:PreferredRecords()
 for cid,c in pairs(self.db.characters) do if preferred[cid] then
  for _,where in ipairs({'bags','bank','mail','equipped'}) do
   for id,count in pairs(type(c[where])=='table' and c[where] or {}) do
    id=tonumber(id); count=tonumber(count) or 0
    local item=id and count>0 and lookup(id)
    if item then
     local p=item.at[cid]
     if not p then
      p={id=cid,name=c.name or '?',you=cid==self.characterID,synced=c.synced,imported=c.imported,
       counted=not self.db.excluded[cid],bags=0,bank=0,mail=0,equipped=0,bagsAt=c.bagsAt,bankAt=c.bankAt,mailAt=c.mailAt,
       realm=c.realm,faction=c.faction}
      item.at[cid]=p; item.places[#item.places+1]=p
     end
     p[where]=p[where]+count; item.total=item.total+count
    end
   end
  end
 end end
 -- Mail you sent that the other character has not collected yet.
 if self.MailInTransit then
  for _,m in ipairs(self:MailInTransit()) do
   for id,count in pairs(type(m.items)=='table' and m.items or {}) do
    id=tonumber(id); count=tonumber(count) or 0
    local item=id and count>0 and lookup(id)
    if item then
     item.places[#item.places+1]={name='In the mail to '..tostring(m.to),transit=true,counted=true,bags=0,bank=0,mail=count,equipped=0,mailAt=m.at}
     item.total=item.total+count
    end
   end
  end
 end
 local list={}
 for _,item in pairs(byItem) do
  if item then
   local function held(p) return p.bags+p.bank+(p.mail or 0)+(p.equipped or 0) end
   table.sort(item.places,function(a,b) if (a.you or false)~=(b.you or false) then return a.you or false end; return held(a)>held(b) end)
   item.at=nil; list[#list+1]=item
  end
 end
 table.sort(list,function(a,b)
  -- Exact name first, then names starting with the query, then most held.
  local q=query:lower(); local ae,be=a.name:lower()==q,b.name:lower()==q
  if ae~=be then return ae end
  local as,bs=a.name:lower():sub(1,#q)==q,b.name:lower():sub(1,#q)==q
  if as~=bs then return as end
  if a.total~=b.total then return a.total>b.total end
  return a.name<b.name
 end)
 local pending=0; for _ in pairs(unnamed) do pending=pending+1 end
 return list,pending
end

-- One plain line per place: "Voidmark Bank: bank 20, bags 2  (bank 2d ago)".
function N:FinderPlace(p)
 if p.transit then return p.name..': '..p.mail..'   sent '..self:Ago(p.mailAt) end
 local parts={}
 if p.bags>0 then parts[#parts+1]='bags '..p.bags end
 if p.bank>0 then parts[#parts+1]='bank '..p.bank end
 if (p.mail or 0)>0 then parts[#parts+1]='mailbox '..p.mail end
 if (p.equipped or 0)>0 then parts[#parts+1]='worn' end
 local age=p.bank>0 and ('bank '..self:Ago(p.bankAt)) or (p.mail or 0)>0 and ('mailbox '..self:Ago(p.mailAt))
  or (not p.you and p.bags>0 and ('bags '..self:Ago(p.bagsAt))) or nil
 local tags={}
 if p.you then tags[#tags+1]='you' end
 if p.faction and self.character and p.faction~=self.character.faction then tags[#tags+1]=p.faction end
 if p.imported then tags[#tags+1]='imported' end
 if not p.counted then tags[#tags+1]='not counted' end
 return p.name..(#tags>0 and (' ('..table.concat(tags,', ')..')') or '')..': '..table.concat(parts,', ')..(age and ('   '..age) or '')
end

-- Characters whose bank has never been seen, so a miss can say why.
function N:FinderBlindSpots()
 local out={}
 for _,c in pairs(self.db.characters) do if not c.bankAt then out[#out+1]=c.name or '?' end end
 table.sort(out); return out
end

function N:RenderFinder(u,query)
 local list,pending=self:FindItems(query)
 local rows={}
 local accent,muted={.78,.6,1},{.65,.6,.72}
 local shown=0
 for _,item in ipairs(list) do
  if shown>=40 then rows[#rows+1]={text='...more matches. Type more of the name.',color=muted}; break end
  shown=shown+1
  rows[#rows+1]={text=item.name..'   x'..item.total,item=item.id,itemName=item.name,color=accent}
  for _,p in ipairs(item.places) do
   rows[#rows+1]={text='     '..self:FinderPlace(p),item=item.id,itemName=item.name,color=p.transit and {1,.85,.4} or (p.counted and nil or {.6,.6,.6})}
  end
 end
 local n=0; for _ in pairs(self.db.characters) do n=n+1 end
 local info
 if #list==0 then
  info='Not found in the bags or banks of '..n..' character'..(n==1 and '' or 's')..'.'
  local blind=self:FinderBlindSpots()
  if #blind>0 then info=info..'\nBank never opened on: '..table.concat(blind,', ')..'. Open it once so Nexus can see it.' end
 else
  local total=0; for _,item in ipairs(list) do total=total+1 end
  info=total..' match'..(total==1 and '' or 'es')..' across '..n..' character'..(n==1 and '' or 's')..'. Bags and gear update live; bank and mailbox when opened.'
 end
 if pending>0 then info=info..'\nLooking up '..pending..' item name'..(pending==1 and '' or 's')..'...' end
 u.syncInfo:SetText(info)
 u.footer:SetText('Clear the search box to see your characters.')
 return rows
end

-- /vmn find NAME: the same answer in chat.
function N:FindCommand(query)
 if query=='' then return self:Print('Usage: /vmn find NAME  (several: /vmn find thick leather, runecloth  -  everything: /vmn find all  -  a kind: /vmn find herbs | ore | leather | cloth | enchanting)') end
 local cat=self:FindCategory(query)
 if cat then return self:CategoryReport(cat) end
 local list=self:FindItems(query)
 if #list==0 then return self:Print('No "'..query..'" in any saved bags or banks.') end
 local limit=(query:find(',',1,true) or query:lower()=='all' or query=='*') and 15 or 5
 for i,item in ipairs(list) do
  if i>limit then self:Print('...and '..(#list-limit)..' more. Open /vmn and use Find for all of them.'); break end
  local places={}
  for _,p in ipairs(item.places) do places[#places+1]=self:FinderPlace(p) end
  self:Print(item.name..' x'..item.total..' - '..table.concat(places,'; '))
 end
end

-- /vmn find herbs (or ore, leather...): every one you hold, where, and its
-- AH value (VoidMark Market prices), most valuable first.
function N:CategoryReport(cat)
 local list,total,count=self:CategoryList(cat)
 if #list==0 then return self:Print('No '..cat.label:lower()..' in any saved bags or banks.') end
 self:Print(cat.label..': '..#list..' kinds, '..count..' total, worth ~'..self:Money(total)..' at AH prices')
 for _,item in ipairs(list) do
  self:Print(('  %s x%d%s'):format(item.name,item.total,item.value and ('  ~'..self:Money(item.value)) or '  (no AH price)'))
 end
end

-- Names arriving from the server refresh an open search.
N:On('GET_ITEM_INFO_RECEIVED',function()
 local u=N.ui
 if u and u.find and u.find:GetText()~='' and u.frame:IsShown() then N:Later('finderNames',function() N.dirty=true end) end
end)

-- /vmn need: what you already have against a shopping list, what's short and
-- what buying the rest costs (VoidMark Market prices).
--   /vmn need 414 light leather, 139 medium leather
--   /vmn need lw    (Leatherworking 1-300, step by step)
N.NEED_PRESETS={
 lw={name='Leatherworking',steps={
  {'1-150',{{105,'Ruined Leather Scraps'},{414,'Light Leather'},{27,'Light Hide'},{139,'Medium Leather'},{10,'Medium Hide'},{30,'Heavy Hide'}}},
  {'150-225',{{126,'Medium Leather'},{397,'Heavy Leather'},{16,'Iron Buckle'},{340,'Thick Leather'}}},
  {'225-300',{{224,'Thick Leather'},{1030,'Rugged Leather'},{530,'Runecloth'}}}}},
}
N.NEED_PRESETS.leatherworking=N.NEED_PRESETS.lw
-- Alchemy 1-300 (Wowhead Forever guide, "to be safe" counts).
N.NEED_PRESETS.alch={name='Alchemy',steps={
 {'1-120',{{55,'Silverleaf'},{81,'Peacebloom'},{44,'Mageroyal'},{56,'Earthroot'},{60,'Briarthorn'},{125,'Empty Vial'}}},
 {'120-225',{{43,'Mageroyal'},{98,'Stranglekelp'},{41,'Kingsblood'},{31,'Goldthorn'},{21,"Khadgar's Whisker"},{45,'Empty Vial'},{72,'Leaded Vial'}}},
 {'225-260',{{4,'Iron Bar'},{1,'Black Vitriol'},{4,'Purple Lotus'},{4,'Firebloom'},{25,'Goldthorn'},{25,"Khadgar's Whisker"},{25,'Leaded Vial'},{26,"Arthas' Tears"},{26,'Crystal Vial'}}},
 {'260-300',{{20,'Sungrass'},{20,'Blindweed'},{33,'Plaguebloom'},{33,'Murloc Eye'},{43,'Crystal Vial'}}}}}
N.NEED_PRESETS.alchemy=N.NEED_PRESETS.alch
-- Item ID for a name: your items, names Nexus saved, then Market's scan.
function N:ItemIDByName(name)
 local want=tostring(name or ''):lower()
 for id,n in pairs(self.db.itemNames or {}) do if type(n)=='string' and n:lower()==want then return tonumber(id) end end
 local m=VoidMarkMarketDB
 m=type(m)=='table' and type(m.economies)=='table' and m.economies[self.economy]
 for k,v in pairs(type(m)=='table' and type(m.market)=='table' and m.market or {}) do
  if type(v)=='table' and type(v.name)=='string' and v.name:lower()==want and (not v.itemSuffix or v.itemSuffix==0) then return tonumber(v.itemID or k) end
 end
 return nil
end
-- How many of exactly this item you hold everywhere.
function N:HaveCount(name)
 for _,item in ipairs(self:FindItems(name)) do
  if item.name:lower()==tostring(name):lower() then return item.total,item.id,item.name end
 end
 local id=self:ItemIDByName(name)
 return 0,id,id and self:FinderName(id) or nil
end
function N:NeedLines(list)
 local lines,shortCost,unknown={},0,0
 for _,e in ipairs(list) do
  local need,name=e[1],e[2]
  local have,id,real=self:HaveCount(name)
  name=real or name
  local short=math.max(0,need-have)
  local line=('%s: have %d / need %d'):format(name,have,need)
  if short==0 then line=line..'  |cff40ff40done|r'
  else
   local p=id and self:Price(id)
   if p and p.unit then
    local c=short*p.unit;shortCost=shortCost+c
    line=line..('  |cffffd200short %d  ~%s|r'):format(short,self:Money(c))
   else unknown=unknown+1;line=line..('  |cffffd200short %d|r  (no AH price)'):format(short) end
  end
  lines[#lines+1]=line
 end
 return lines,shortCost,unknown
end
function N:NeedCommand(args)
 args=tostring(args or ''):match('^%s*(.-)%s*$')
 local preset=self.NEED_PRESETS[args:lower()]
 if preset then
  local total=0
  self:Print(preset.name..' - what you have and what the rest costs:')
  for _,step in ipairs(preset.steps) do
   local lines,cost,unknown=self:NeedLines(step[2]);total=total+cost
   self:Print('|cffc8a0ff'..step[1]..'|r  buy ~'..self:Money(cost)..(unknown>0 and ' (+'..unknown..' without an AH price)' or ''))
   for _,l in ipairs(lines) do self:Print('  '..l) end
  end
  return self:Print('Total to buy: ~'..self:Money(total))
 end
 local list={}
 for part in (args..','):gmatch('([^,]*),') do
  local n,name=part:match('^%s*(%d+)%s*x?%s+(.-)%s*$')
  if n and name~='' then list[#list+1]={tonumber(n),name} end
 end
 if #list==0 then return self:Print('Usage: /vmn need 414 light leather, 139 medium leather   or   /vmn need lw | alch') end
 local lines,cost,unknown=self:NeedLines(list)
 for _,l in ipairs(lines) do self:Print(l) end
 self:Print('To buy: ~'..self:Money(cost)..(unknown>0 and ' (+'..unknown..' without an AH price)' or ''))
end

-- Reports (Reports button in the window) ------------------------------------
N.REPORTS={
 {key='herbs',label='Herb report'},
 {key='ore',label='Ore, bars and stone report'},
 {key='leather',label='Leather and hides report'},
 {key='cloth',label='Cloth report'},
 {key='enchanting',label='Enchanting materials report'},
 {key='need:alch',label='Alchemy 1-300: have / need'},
 {key='need:lw',label='Leatherworking 1-300: have / need'},
}
-- Items of a kind you hold, most valuable first, with total AH value.
function N:CategoryList(cat)
 local list=self:FindItems(cat.word)
 local total,count=0,0
 for _,item in ipairs(list) do
  local p=self:Price(item.id);item.value=p and p.unit and p.unit*item.total or nil
  if item.value then total=total+item.value end;count=count+item.total
 end
 table.sort(list,function(a,b) if (a.value or -1)~=(b.value or -1) then return (a.value or -1)>(b.value or -1) end return a.name<b.name end)
 return list,total,count
end
function N:RenderReport(u,key)
 local rows={}
 local accent,muted,gold={.78,.6,1},{.65,.6,.72},{1,.82,0}
 local preset=key:match('^need:(.+)$')
 if preset then
  local p=self.NEED_PRESETS[preset]
  local total=0
  for _,step in ipairs(p.steps) do
   local lines,cost,unknown=self:NeedLines(step[2]);total=total+cost
   rows[#rows+1]={text=step[1]..'   buy ~'..self:Money(cost)..(unknown>0 and ('  (+'..unknown..' without an AH price)') or ''),color=accent}
   for i,l in ipairs(lines) do rows[#rows+1]={text='     '..l,itemName=step[2][i][2]} end
  end
  u.syncInfo:SetText(p.name..' 1-300: what you have on every character against the leveling list.\nTotal to buy the rest: ~'..self:Money(total)..' (VoidMark Market prices).')
  u.footer:SetText('Bags and gear update live; bank and mailbox when opened. Reports button: pick another.')
  return rows
 end
 local cat=self.FIND_CATEGORIES[key];if not cat then return rows end
 local list,total,count=self:CategoryList(cat)
 for _,item in ipairs(list) do
  rows[#rows+1]={text=item.name..'   x'..item.total..'   '..(item.value and ('~'..self:Money(item.value)) or 'no AH price'),item=item.id,itemName=item.name,color=item.value and nil or muted}
  for _,p in ipairs(item.places) do
   rows[#rows+1]={text='     '..self:FinderPlace(p),item=item.id,itemName=item.name,color=p.transit and {1,.85,.4} or (p.counted and muted or {.5,.5,.5})}
  end
 end
 if #list==0 then rows[1]={text='None in any saved bags, banks or mailboxes.',color=muted} end
 u.syncInfo:SetText(cat.label..': '..#list..' kinds, '..count..' total, worth ~'..self:Money(total)..' at AH prices (VoidMark Market).')
 u.footer:SetText('Most valuable first. Bank and mailbox count from when you last opened them.')
 return rows
end
