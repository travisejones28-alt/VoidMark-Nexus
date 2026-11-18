local _, N = ...
-- Item tooltips show how many of the item your characters hold (same realm and
-- faction), including the bank character synced from the other account.

-- Same counting as Reports: every character (both accounts, same realm and
-- faction), bags+bank+mailbox, and mail on its way counted as the recipient's.
function N:ItemCounts(id)
 id=tonumber(id); if not id or not self.db then return 0,{} end
 local me=self.character
 local item=self:FindItems('item:'..id)[1]
 if not item then return 0,{} end
 local places={}
 for _,p in ipairs(item.places) do
  local ok=p.transit or (p.counted and self:SameRealm(p.realm,me.realm) and p.faction==me.faction
   and (not p.imported or p.synced or self.db.settings.includeImports))
  if ok then places[#places+1]=p end
 end
 local list,total=self:OwnerEntries(places),0
 for _,e in ipairs(list) do total=total+e.n end
 table.sort(list,function(a,b) if (a.you or false)~=(b.you or false) then return a.you or false end return a.n>b.n end)
 return total,list
end

function N:AddItemCounts(tooltip,id)
 if not self.ready or not self.db.settings.tooltipCounts or not tooltip or not tooltip.AddLine then return end
 id=tonumber(id); if not id then return end
 if tooltip.vmnItem==id then return end
 local total,list=self:ItemCounts(id)
 if total==0 then return end
 tooltip.vmnItem=id
 local function line(e) return e.n..(e.where~='' and (' ('..e.where..')') or '') end
 if #list==1 then
  tooltip:AddDoubleLine(list[1].who,line(list[1]),.78,.6,1,1,1,1)
 else
  -- Total first, then who holds them.
  tooltip:AddDoubleLine('Held: '..total,'',.78,.6,1,1,1,1)
  for i,e in ipairs(list) do
   if i>6 then tooltip:AddLine('  ...and '..(#list-6)..' more',.6,.55,.7); break end
   tooltip:AddDoubleLine('  '..e.who,line(e),.78,.6,1,1,1,1)
  end
 end
 if tooltip.Show then tooltip:Show() end
end

function N:AddNexusTooltip(tooltip,id)
 self:AddItemCounts(tooltip,id)
 if self.AddDisenchantTooltip then self:AddDisenchantTooltip(tooltip,id) end
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
   N:Guard('tooltip',function() N:AddNexusTooltip(tooltip,type(data)=='table' and data.id or linkID(tooltip)) end)
  end)
 end
 for _,tt in ipairs({GameTooltip,ItemRefTooltip}) do
  if tt and tt.HookScript then
   if not hooked then pcall(tt.HookScript,tt,'OnTooltipSetItem',function(t) N:Guard('tooltip',function() N:AddNexusTooltip(t,linkID(t)) end) end) end
   pcall(tt.HookScript,tt,'OnTooltipCleared',function(t) t.vmnItem=nil; t.vmnDE=nil end)
   pcall(tt.HookScript,tt,'OnHide',function(t) t.vmnItem=nil; t.vmnDE=nil end)
  end
 end
end
