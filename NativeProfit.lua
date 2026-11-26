local _, N = ...
-- 0.15.0: profit inside the game's own profession window.
-- Each recipe row gets its profit on the right, and the selected recipe gets a
-- small box under its reagents: cost, sale price, net profit. Same numbers as
-- Nexus > Professions > Profit (VoidMark Market prices, AH cut, your settings).
-- Only post-hooks and our own font strings: nothing Blizzard owns is replaced.

local function short(n)
 if not N:Finite(n,-1e15,1e15) then return nil end
 local sign=n<0 and '-' or '+'; n=math.floor(math.abs(n)+.5)
 local g,s,c=math.floor(n/10000),math.floor(n/100)%100,n%100
 if g>=100 then return sign..g..'g' end
 if g>0 then return sign..g..'g '..s..'s' end
 if s>0 then return sign..s..'s '..c..'c' end
 return sign..c..'c'
end
N.ShortMoney=function(_,n) return short(n) end

-- The recipe Nexus scanned for this profession window row (looked up by name,
-- because row indexes change when headers collapse or a filter is used).
function N:NativeRecipe(index)
 local pid=self.activeProfession; local c=self.character
 local p=pid and c and c.professions and c.professions[pid]
 if not p or type(p.recipes)~='table' or not index then return nil end
 local name,kind=self:Call(GetTradeSkillInfo,index)
 if not self:Text(name) or kind=='header' then return nil end
 if p.byNameAt~=p.at or not p.byName then
  p.byName={}; for _,r in pairs(p.recipes) do if type(r)=='table' and r.name then p.byName[r.name]=r end end
  p.byNameAt=p.at
 end
 return p.byName[name]
end

function N:NativeProfit(index)
 local r=self:NativeRecipe(index)
 if not r or not r.output then return nil end
 local e=self:Evaluate(r,1,self.characterID)
 return e,r
end

local function color(n) return n>=0 and '|cff40ff40' or '|cffff5050' end

function N:UpdateNativeRows()
 if not self.db.settings.nativeProfit then
  for i=1,(TRADE_SKILLS_DISPLAYED or 8) do local b=_G['TradeSkillSkill'..i]; if b and b.vmnProfit then b.vmnProfit:SetText('') end end
  return
 end
 for i=1,(TRADE_SKILLS_DISPLAYED or 8) do
  local b=_G['TradeSkillSkill'..i]
  if b then
   if not b.vmnProfit and b.CreateFontString then
    local fs=b:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
    fs:SetPoint('RIGHT',b,'RIGHT',-4,0); fs:SetJustifyH('RIGHT'); b.vmnProfit=fs
   end
   if b.vmnProfit then
    local text=''
    if b.IsShown and b:IsShown() and b.GetID then
     local e=self:NativeProfit(b:GetID())
     local v=e and e.economic
     if v then text=color(v)..short(v)..'|r' end
    end
    b.vmnProfit:SetText(text)
   end
  end
 end
end

function N:UpdateNativeDetail(index)
 local host=rawget(_G,'TradeSkillDetailScrollChildFrame')
 if type(host)~='table' or not host.CreateFontString then return end
 if not self.nativeDetail then
  local fs=host:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  fs:SetJustifyH('LEFT'); if fs.SetWidth then fs:SetWidth(280) end
  self.nativeDetail=fs
 end
 local fs=self.nativeDetail
 index=index or self:Call(GetTradeSkillSelectionIndex)
 local e,r=self:NativeProfit(index)
 if not self.db.settings.nativeProfit or not e then fs:SetText(''); return end
 -- Under the last reagent shown for this recipe.
 local n=self:Call(GetTradeSkillNumReagents,index) or 0
 local anchor=_G['TradeSkillReagent'..math.max(1,math.min(8,n))]
 fs:ClearAllPoints()
 if anchor then fs:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-8) else fs:SetPoint('TOPLEFT',host,'TOPLEFT',8,-200) end
 local lines={'|cffb56cffProfit (VoidMark Nexus)|r'}
 lines[#lines+1]='Cost to craft: '..(e.cost and self:Money(e.cost) or 'unknown price')
 if e.sale and e.sale.unit then
  local each=(e.output or 1)>1 and (' for '..e.output) or ''
  lines[#lines+1]='Sells for: '..self:Money(e.sale.unit*(e.output or 1))..each..' (after '..math.floor((self.db.settings.cut or .05)*100+.5)..'% AH cut: '..self:Money(e.net or 0)..')'
 elseif r.bound then lines[#lines+1]='Sells for: binds when picked up'
 else lines[#lines+1]='Sells for: no Market price yet' end
 if e.economic then
  local pct=e.margin and string.format(' (%d%%)',math.floor(e.margin*100+.5)) or ''
  lines[#lines+1]='Net profit: '..color(e.economic)..self:Money(e.economic)..pct..'|r'
 end
 if e.stale then lines[#lines+1]='|cffaaaaaaSome prices are old; run a Market scan.|r' end
 fs:SetText(table.concat(lines,'\n'))
end

function N:HookNativeProfit()
 if self.nativeProfitHooked or type(hooksecurefunc)~='function' then return end
 if type(rawget(_G,'TradeSkillFrame_Update'))~='function' then return end
 self.nativeProfitHooked=true
 hooksecurefunc('TradeSkillFrame_Update',function() N:Guard('native profit',function() N:UpdateNativeRows(); N:UpdateNativeDetail() end) end)
 if type(rawget(_G,'TradeSkillFrame_SetSelection'))=='function' then
  hooksecurefunc('TradeSkillFrame_SetSelection',function(id) N:Guard('native profit',function() N:UpdateNativeDetail(id) end) end)
 end
end

N:On('TRADE_SKILL_SHOW',function() N:Later('nativeProfit',function() N:HookNativeProfit(); N:UpdateNativeRows(); N:UpdateNativeDetail() end) end)
-- Rows refresh again once the recipe scan has filled in names and reagents.
N:On('TRADE_SKILL_UPDATE',function() N:Later('nativeProfitRows',function() N:UpdateNativeRows(); N:UpdateNativeDetail() end) end)
