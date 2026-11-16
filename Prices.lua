local _, N = ...
N.integrationVersion=1
function N:Price(id)
 if not self:Finite(id,1,1e9) or id%1~=0 then return nil end
 local settings=self.db.settings; local cache=self.prices[id]
 if type(cache)~='table' then cache=nil end
 local function record(unit,at,source,confidence)
  if not self:Finite(unit,0,1e12) or not self:Finite(at,0,self:Now()+300) then return nil end
  return {unit=unit,at=at,source=source,confidence=confidence,stale=self:Now()-at>settings.maxAge}
 end
 if settings.manualFirst and cache and type(cache.manual)=='table' then return record(cache.manual.unit,cache.manual.at,'Manual') end
 if settings.market and type(VoidMarkMarketDB)=='table' and VoidMarkMarketDB.schemaVersion==1 then
  local economies=VoidMarkMarketDB.economies
  -- Market 1.23.29+ names the realm without spaces; older saves may still have them.
  local economy=type(economies)=='table' and (economies[(tostring(self.economy):gsub('%s',''))] or economies[self.economy])
  local m=type(economy)=='table' and type(economy.market)=='table' and (economy.market[id] or economy.market[tostring(id)])
  if type(m)=='table' and (not m.itemSuffix or m.itemSuffix==0) and type(m.latest)=='table' then
   local p=record(m.fairValue or m.latest.median,m.lastSeen or m.latest.at,'VoidMark Market',m.confidenceScore)
   if p then
    self.prices[id]=cache or {}; self.prices[id].cached={unit=p.unit,at=p.at}
    -- Market's own read-only status (1.23+): stale snapshots, untrusted caches and
    -- developing markets are flagged rather than trusted. Never changes the price.
    if m.cacheUntrusted or m.analysisIncomplete then p.stale=true; p.untrusted=true end
    if m.developingMarket then p.developing=true end
    local api=VoidMarkMarket
    if type(api)=='table' and type(api.GetPriceInfo)=='function' and api.db then
     local info=self:Call(api.GetPriceInfo,api,id)
     if type(info)=='table' and info.apiVersion==1 and type(info.status)=='string' then
      p.marketStatus=info.status
      if info.status~='current' then p.stale=true end
     end
    end
    return p
   end
  end
 end
 if settings.auctionator and Auctionator and Auctionator.API and Auctionator.API.v1 then
  local unit=self:Call(Auctionator.API.v1.GetAuctionPriceByItemID,'VoidMarkNexus',id)
  -- This adapter has no verified scan timestamp: do not pretend the cache was scanned now.
  if self:Finite(unit,1,1e12) then return {unit=unit,source='Auctionator (age unknown)',stale=true} end
 end
 if cache and type(cache.cached)=='table' then local p=record(cache.cached.unit,cache.cached.at,'Nexus cache'); if p then return p end end
 if cache and type(cache.manual)=='table' then return record(cache.manual.unit,cache.manual.at,'Manual') end
 return nil
end
-- Plain description of where a price came from and how far to trust it.
-- Market confidence is 0-100; under 40 means few or unstable observations.
function N:PriceLabel(p)
 if type(p)~='table' then return 'Unknown price' end
 local parts={self:Money(p.unit),p.source or 'Unknown source',p.at and self:Age(p.at) or 'age unknown'}
 if self:Finite(p.confidence,0,100) then
  parts[#parts+1]=string.format('confidence %d/100%s',p.confidence,p.confidence<40 and ' (low - sparse data)' or '')
 end
 if p.developing then parts[#parts+1]='developing market' end
 if p.untrusted then parts[#parts+1]='unverified scan' end
 if p.stale then parts[#parts+1]='STALE' end
 return table.concat(parts,' / ')
end
function N:SetPrice(id,gold)
 id=tonumber(id); gold=tonumber(gold)
 if not self:Finite(id,1,1e9) or id%1~=0 or not self:Finite(gold,0,1e8) then return self:Print('Enter an item ID and nonnegative price in gold.') end
 self.prices[id]=type(self.prices[id])=='table' and self.prices[id] or {}; self.prices[id].manual={unit=math.floor(gold*10000+.5),at=self:Now()}; self.priceStamp=(self.priceStamp or 0)+1; self.dirty=true
end
function N:OpenMarket(item)
 local m=VoidMarkMarket
 if not (m and m.ToggleUI and m.db) then return self:Print('Compatible VoidMark Market is not loaded.') end
 -- 0.11: open Market's search (browse) view filtered to this item. Read-only:
 -- nothing is bought, posted or cancelled.
 m.db.settings.filter=self:ItemName(item); m.view='browse'
 if m.SetView then m:SetView('browse') elseif m.window and not m.window:IsShown() then m:ToggleUI() end
 if m.filter then m.filter:SetText(m.db.settings.filter) end
 if m.RefreshUI then m:RefreshUI() end
end
