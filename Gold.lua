local _,N=...
-- Gold on every character: read on login and whenever it changes, synced to the
-- other account with the bag/bank data, shown on the Characters page.

function N:ScanMoney()
 if not self.character then return end
 local money=tonumber(self:Call(GetMoney))
 if not self:Finite(money,0,1e13) then return end
 money=math.floor(money)
 local changed=self.character.money~=money
 self.character.money=money; self.character.moneyAt=self:Now()
 if changed then self.dirty=true; if self.SyncSoon then self:SyncSoon() end end
end

-- "12,345g 67s" (copper is noise at this scale).
function N:Gold(copper)
 copper=tonumber(copper); if not copper then return '?' end
 local g=math.floor(copper/10000); local s=math.floor(copper/100)%100
 local text=tostring(g):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
 return text..'g '..s..'s'
end

-- Gold per real character (older copies skipped) and the total.
function N:GoldSummary()
 local preferred=self:PreferredRecords()
 local list,total,unknown={},0,0
 for cid,c in pairs(self.db.characters) do
  if preferred[cid] then
   local m=tonumber(c.money)
   if m then total=total+m else unknown=unknown+1 end
   list[#list+1]={id=cid,name=c.name or '?',money=m,at=c.moneyAt,you=cid==self.characterID,synced=c.synced,imported=c.imported,faction=c.faction}
  end
 end
 table.sort(list,function(a,b) if a.you~=b.you then return a.you end; return (a.money or -1)>(b.money or -1) end)
 return total,list,unknown
end

function N:GoldLine()
 local total,list,unknown=self:GoldSummary()
 local known=#list-unknown
 if known==0 then return nil end
 local line='Gold: '..self:Gold(total)..' on '..known..' character'..(known==1 and '' or 's')
 if unknown>0 then line=line..' ('..unknown..' not seen yet, log in once)' end
 return line
end

-- /vmn gold: per character in chat.
function N:GoldCommand()
 local total,list=self:GoldSummary()
 for _,g in ipairs(list) do
  self:Print(g.name..(g.you and ' (you)' or '')..': '..(g.money and (self:Gold(g.money)..(g.you and '' or ('  ('..self:Ago(g.at)..')'))) or 'not seen yet'))
 end
 self:Print('Total: '..self:Gold(total))
end

N:On('PLAYER_MONEY',function() N:ScanMoney() end)
N:On('PLAYER_ENTERING_WORLD',function() N:ScanMoney() end)
