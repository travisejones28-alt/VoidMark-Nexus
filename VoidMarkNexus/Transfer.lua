local _, N = ...
local function encode(v,depth)
 assert(depth<16,'Data nesting limit')
 local t=type(v)
 if t=='string' then return 's'..#v..':'..v end
 if t=='number' then assert(v==v and math.abs(v)<1e15,'Invalid number'); return 'n'..tostring(v)..';' end
 if t=='boolean' then return v and 't' or 'f' end
 assert(t=='table','Unsupported value')
 local keys={}; for k in pairs(v) do keys[#keys+1]=k end
 table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
 local out={'{' }; for _,k in ipairs(keys) do out[#out+1]=encode(k,depth+1); out[#out+1]=encode(v[k],depth+1) end
 out[#out+1]='}'; return table.concat(out)
end
function N:Decode(raw)
 assert(type(raw)=='string' and #raw<=2000000,'Export too large (2 MB maximum)')
 assert(raw:sub(1,5)=='VMN1:','Unsupported export version')
 local pos,count=6,0
 local function read(depth)
  count=count+1; assert(depth<16 and count<180000,'Export complexity limit')
  local tag=raw:sub(pos,pos); pos=pos+1
  if tag=='s' then
   local finish=raw:find(':',pos,true); assert(finish and finish-pos<=7,'Invalid string')
   local size=tonumber(raw:sub(pos,finish-1)); assert(size and size>=0 and size<=200000 and size%1==0,'Invalid length')
   pos=finish+1; assert(pos+size-1<=#raw,'Truncated string'); local value=raw:sub(pos,pos+size-1); pos=pos+size; return value
  elseif tag=='n' then
   local finish=raw:find(';',pos,true); assert(finish and finish-pos<=24,'Invalid number')
   local value=tonumber(raw:sub(pos,finish-1)); assert(N:Finite(value,-1e14,1e14),'Invalid number'); pos=finish+1; return value
  elseif tag=='t' then return true elseif tag=='f' then return false
  elseif tag=='{' then
   local value={}
   while raw:sub(pos,pos)~='}' do
    assert(pos<=#raw,'Truncated table'); local key=read(depth+1)
    assert(type(key)=='string' or type(key)=='number','Invalid table key'); assert(value[key]==nil,'Duplicate table key')
    value[key]=read(depth+1)
   end
   pos=pos+1; return value
  end
  error('Invalid export token')
 end
 local value=read(0); assert(pos==#raw+1,'Trailing export data'); return value
end
function N:Export()
 local chars={}; for id,c in pairs(self.db.characters) do if not c.imported then chars[id]=c end end
 local raw='VMN1:'..encode({schema=1,account=self.db.account,characters=chars},0)
 assert(#raw<=2000000,'Export exceeds 2 MB. Export fewer characters in a future version.'); return raw
end
local function text(v,limit) return type(v)=='string' and #v>0 and #v<=(limit or 200) end
local function inventory(t)
 assert(type(t)=='table','Missing inventory')
 local n=0; for id,qty in pairs(t) do n=n+1; assert(n<=5000 and N:Finite(id,1,1e9) and id%1==0 and N:Finite(qty,0,1e9) and qty%1==0,'Invalid inventory') end
end
function N:ValidateCharacter(c)
 assert(type(c)=='table' and text(c.name) and text(c.realm) and text(c.faction) and text(c.account),'Invalid character identity')
 assert(self:Finite(c.at,0,self:Now()+300),'Invalid timestamp')
 if c.guid then assert(text(c.guid),'Invalid GUID') end
 inventory(c.bags); inventory(c.bank)
 for _,k in ipairs({'bagsAt','bankAt'}) do if c[k] then assert(self:Finite(c[k],0,self:Now()+300),'Invalid inventory timestamp') end end
 assert(type(c.professions)=='table','Missing professions')
 local np,nr=0,0
 for pid,p in pairs(c.professions) do
  np=np+1; assert(np<=100 and text(pid) and type(p)=='table' and text(p.name),'Invalid profession')
  assert(self:Finite(p.skill or 0,0,10000) and self:Finite(p.max or 0,0,10000),'Invalid profession skill')
  if p.at then assert(self:Finite(p.at,0,self:Now()+300),'Invalid profession timestamp') end
  assert(type(p.recipes or {})=='table','Invalid recipes')
  for rid,r in pairs(p.recipes or {}) do
   nr=nr+1; assert(nr<=10000 and text(rid) and type(r)=='table' and text(r.name) and type(r.learned)=='boolean','Invalid recipe')
   assert(type(r.reagents)=='table' and #r.reagents<=50,'Invalid reagents')
   if r.at then assert(self:Finite(r.at,0,self:Now()+300),'Invalid recipe timestamp') end
   if r.difficulty then assert(type(r.difficulty)=='string' or self:Finite(r.difficulty,0,10),'Invalid difficulty') end
   if r.cooldown then assert(self:Finite(r.cooldown,0,1e9),'Invalid cooldown') end
   assert(self:Finite(r.outputMin or 1,1,1e6) and self:Finite(r.outputMax or 1,1,1e6),'Invalid output')
   if r.output then assert(self:Finite(r.output,1,1e9) and r.output%1==0,'Invalid item') end
   for _,g in ipairs(r.reagents) do assert(type(g)=='table' and self:Finite(g.qty,1,1e6) and (g.id==nil or self:Finite(g.id,1,1e9) and g.id%1==0),'Invalid reagent') end
   if r.source then assert(type(r.source)=='string' and #r.source<=10000,'Invalid source') end
  end
 end
 return true
end
function N:CleanImported(c)
 local out={name=c.name,realm=c.realm,faction=c.faction,guid=c.guid,account=c.account,at=c.at,
  bags=self:Copy(c.bags),bank=self:Copy(c.bank),bagsAt=c.bagsAt,bankAt=c.bankAt,professions={}}
 for pid,p in pairs(c.professions) do
  local prof={name=p.name,skill=p.skill or 0,max=p.max or 0,at=p.at,recipes={}}; out.professions[pid]=prof
  for rid,r in pairs(p.recipes or {}) do
   local recipe={name=r.name,learned=r.learned,output=r.output,outputMin=r.outputMin or 1,outputMax=r.outputMax or r.outputMin or 1,
    at=r.at,difficulty=r.difficulty,cooldown=r.cooldown,source=r.source,incomplete=r.incomplete==true,bound=r.bound==true,disabled=r.disabled==true,reagents={}}
   for _,g in ipairs(r.reagents) do recipe.reagents[#recipe.reagents+1]={id=g.id,qty=g.qty} end
   prof.recipes[rid]=recipe
  end
 end
 return out
end
function N:PreviewImport(raw)
 self.pendingImport=nil
 local ok,data=pcall(self.Decode,self,raw); if not ok then return nil,data end
 local accepted,lines={},{}
 local valid,err=pcall(function()
  assert(type(data)=='table' and data.schema==1 and text(data.account) and data.account~=self.db.account,'Import must come from a different account')
  assert(type(data.characters)=='table','Missing characters'); local n=0
  for id,c in pairs(data.characters) do
   n=n+1; assert(n<=100 and text(id,600),'Character limit or invalid identity'); self:ValidateCharacter(c)
   assert(c.account==data.account and id==c.account..'/'..c.realm..'/'..c.name,'Character identity mismatch')
   local existing=self.db.characters[id]; local conflict=false
   for otherID,other in pairs(self.db.characters) do
    if otherID~=id and ((c.guid and other.guid==c.guid) or (other.realm==c.realm and other.name==c.name)) then conflict=true end
   end
   if conflict then lines[#lines+1]=c.name..': skipped (identity conflict)'
   elseif existing and (not existing.imported or existing.at>=c.at or (existing.bagsAt or 0)>(c.bagsAt or 0) or (existing.bankAt or 0)>(c.bankAt or 0)) then lines[#lines+1]=c.name..': skipped (local/newer data)'
   else
    if existing then for pid,p in pairs(c.professions) do local old=existing.professions[pid]; if old and (old.at or 0)>(p.at or 0) then c.professions[pid]=old end end end
    accepted[id]=self:CleanImported(c); lines[#lines+1]=c.name..' - '..c.realm..': '..(existing and 'replace imported record' or 'add imported character')..' ('..self:Age(c.at)..')'
   end
  end
 end)
 if not valid then return nil,err end
 self.pendingImport={raw=raw,accepted=accepted}; return table.concat(lines,'\n')
end
function N:ConfirmImport()
 local pending=self.pendingImport; if not pending then return end
 local preview,err=self:PreviewImport(pending.raw); if not preview then return self:Print(err) end
 for id,c in pairs(self.pendingImport.accepted) do c.imported=true; self.db.characters[id]=c end
 self.pendingImport=nil; self.dirty=true; self:Print('Import complete. Imported inventory is excluded until enabled in Settings.')
end
