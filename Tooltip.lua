local _, N = ...
-- Item tooltips show how many of the item your characters hold (same realm and
-- faction), including the bank character synced from the other account.

-- Returns total and a list of {name, bags, bank} for the item.
function N:ItemCounts(id)
 id=tonumber(id); if not id or not self.db then return 0,{} end
 local me=self.character; local total,list,seen=0,{},{}
 for cid,c in pairs(self.db.characters) do
  local physical=c.guid or ((c.realm or '')..'/'..(c.name or ''))
  local allowed=self:SameRealm(c.realm,me.realm) and c.faction==me.faction and not self.db.excluded[cid] and not seen[physical]
   and (not c.imported or c.synced or self.db.settings.includeImports)
  if allowed then
   seen[physical]=true
   local bags=tonumber(c.bags and c.bags[id]) or 0
   local bank=tonumber(c.bank and c.bank[id]) or 0
   if bags+bank>0 then
    total=total+bags+bank
    list[#list+1]={name=c.name,bags=bags,bank=bank,own=cid==self.characterID}
   end
  end
 end
 table.sort(list,function(a,b) if a.own~=b.own then return a.own end return (a.bags+a.bank)>(b.bags+b.bank) end)
 return total,list
end

function N:AddItemCounts(tooltip,id)
 if not self.ready or not self.db.settings.tooltipCounts or not tooltip or not tooltip.AddLine then return end
 id=tonumber(id); if not id then return end
 if tooltip.vmnItem==id then return end
 local total,list=self:ItemCounts(id)
 if total==0 then return end
 tooltip.vmnItem=id
 local single=#list==1 and list[1].own
 for i,e in ipairs(list) do
  if i>6 then tooltip:AddLine('  ...and '..(#list-6)..' more',.6,.55,.7); break end
  local parts={}
  if e.bags>0 then parts[#parts+1]='bags '..e.bags end
  if e.bank>0 then parts[#parts+1]='bank '..e.bank end
  tooltip:AddDoubleLine((single and '' or '  ')..e.name,table.concat(parts,', '),.78,.6,1,1,1,1)
 end
 if not single then tooltip:AddDoubleLine('  Total',tostring(total),.78,.6,1,1,1,1) end
 if tooltip.Show then tooltip:Show() end
end

local function linkID(tooltip)
 if not tooltip.GetItem then return end
 local ok,_,link=pcall(tooltip.GetItem,tooltip)
 return ok and N:ItemID(link)
end

function N:HookTooltips()
 if self.tooltipsHooked then return end
 self.tooltipsHooked=true
 local hooked=false
 if type(TooltipDataProcessor)=='table' and type(TooltipDataProcessor.AddTooltipPostCall)=='function'
  and type(Enum)=='table' and type(Enum.TooltipDataType)=='table' and Enum.TooltipDataType.Item then
  hooked=pcall(TooltipDataProcessor.AddTooltipPostCall,Enum.TooltipDataType.Item,function(tooltip,data)
   N:Guard('tooltip',function() N:AddItemCounts(tooltip,type(data)=='table' and data.id or linkID(tooltip)) end)
  end)
 end
 for _,tt in ipairs({GameTooltip,ItemRefTooltip}) do
  if tt and tt.HookScript then
   if not hooked then pcall(tt.HookScript,tt,'OnTooltipSetItem',function(t) N:Guard('tooltip',function() N:AddItemCounts(t,linkID(t)) end) end) end
   pcall(tt.HookScript,tt,'OnTooltipCleared',function(t) t.vmnItem=nil end)
   pcall(tt.HookScript,tt,'OnHide',function(t) t.vmnItem=nil end)
  end
 end
end
