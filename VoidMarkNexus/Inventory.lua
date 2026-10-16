local _, N = ...
function N:ScanStorage(bank)
 if bank and not self.bankOpen then return end
 local api=C_Container or _G; local slots=api.GetContainerNumSlots or GetContainerNumSlots
 local info=api.GetContainerItemInfo or GetContainerItemInfo
 if type(slots)~='function' or type(info)~='function' then return end
 local result={}; local links={}; local bags={}; local readable=false
 if bank then
  bags={BANK_CONTAINER or -1}; for i=(NUM_BAG_SLOTS or 4)+1,(NUM_BAG_SLOTS or 4)+(NUM_BANKBAGSLOTS or 7) do bags[#bags+1]=i end
 else for i=0,(NUM_BAG_SLOTS or 4) do bags[#bags+1]=i end end
 for _,bag in ipairs(bags) do
  local size=self:Call(slots,bag)
  if self:Finite(size,0,200) then readable=true; for slot=1,size do
   readable=true
   local a,count,_,_,_,_,link=self:Call(info,bag,slot); local id
   if type(a)=='table' then id=a.itemID or self:ItemID(a.hyperlink); count=a.stackCount; link=a.hyperlink else id=self:ItemID(link) end
   if id and self:Finite(count,1,1e9) then result[id]=(result[id] or 0)+count; if type(link)=='string' and link:find('item:',1,true) then links[id]=link; self.db.itemNames[id]=link:match('%[(.-)%]') end end
  end end
 end
 if not readable then return end -- do not wipe snapshots while storage API data is unavailable
 local key=bank and 'bank' or 'bags'; self.character[key]=result; self.character.itemLinks=self.character.itemLinks or {}; self.character.itemLinks[key]=links; self.character[key..'At']=self:Now(); self.character.at=self:Now(); self.dirty=true
end
N:On('BAG_UPDATE_DELAYED',function() N:Later('bags',function() N:ScanStorage(false); if N.bankOpen then N:ScanStorage(true) end end) end)
N:On('BANKFRAME_OPENED',function() N.bankOpen=true; N:ScanStorage(true) end)
N:On('BANKFRAME_CLOSED',function() N.bankOpen=false end)

