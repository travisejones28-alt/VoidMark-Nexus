local _,N=...
-- Mail and worn gear, so Find item covers everywhere an item can be:
--  * the mailbox is read when you open it (items waiting to be collected)
--  * mail you send with items is remembered as "in the mail to X" until X opens
--    their mailbox (or 30 days pass, when unclaimed mail would have gone back)
--  * equipped gear is read at login and whenever it changes

local MAIL_DAYS=30
local SEND_MAX=12

local function itemFromLink(link)
 return type(link)=='string' and tonumber(link:match('item:(%d+)')) or nil
end

-- Inbox: every attachment still waiting in the mailbox.
function N:ScanMail()
 if not self.character or type(GetInboxNumItems)~='function' then return end
 local count=tonumber((self:Call(GetInboxNumItems)))
 if not self:Finite(count,0,1000) then return end
 local items,readable={},true
 local maxAttach=tonumber(ATTACHMENTS_MAX_RECEIVE) or 16
 for i=1,count do
  local hasItem=select(8,self:Call(GetInboxHeaderInfo,i))
  if hasItem then
   for a=1,maxAttach do
    local name,id,_,qty=self:Call(GetInboxItem,i,a)
    if name or id then
     id=tonumber(id) or itemFromLink(self:Call(GetInboxItemLink,i,a))
     qty=tonumber(qty) or 1
     if id and self:Finite(qty,1,1e6) then
      items[id]=(items[id] or 0)+qty
      if type(name)=='string' and name~='' then self.db.itemNames[id]=self.db.itemNames[id] or name end
     elseif name then readable=false end
    end
   end
  end
 end
 if not readable then return end -- item data still loading: keep the last good read
 local c=self.character
 c.mail=items; c.mailAt=self:Now(); c.at=self:Now(); self.dirty=true
 -- Mail sent to you before now has arrived (or been read here): drop those notes.
 self:ClearSentMailTo(c.name,c.mailAt)
 if self.SyncSoon then self:SyncSoon() end
end

-- Worn gear (and bag slots' bags count as worn too).
function N:ScanEquipped()
 if not self.character or type(GetInventoryItemID)~='function' then return end
 local items={}
 for slot=1,19 do
  local id=tonumber((self:Call(GetInventoryItemID,'player',slot)))
  if id then items[id]=(items[id] or 0)+1 end
 end
 local c=self.character
 c.equipped=items; c.equippedAt=self:Now(); self.dirty=true
end

--------------------------------------------------------------------------------
-- Sent mail
--------------------------------------------------------------------------------
function N:SentMail()
 local s=self.db.sentMail
 if type(s)~='table' then s={}; self.db.sentMail=s end
 return s
end
local function key(name) return N.SyncKey and N.SyncKey(name) or (type(name)=='string' and name:lower()) or nil end

-- Called right before the game sends: remember what is attached.
function N:CaptureOutgoingMail(recipient)
 if type(recipient)~='string' or recipient=='' or type(GetSendMailItem)~='function' then return end
 local items,any={},false
 for a=1,(tonumber(ATTACHMENTS_MAX_SEND) or SEND_MAX) do
  local name,id,_,qty=self:Call(GetSendMailItem,a)
  if name or id then
   id=tonumber(id) or itemFromLink(self:Call(GetSendMailItemLink,a))
   qty=tonumber(qty) or 1
   if id and self:Finite(qty,1,1e6) then items[id]=(items[id] or 0)+qty; any=true end
  end
 end
 self.outgoingMail=any and {to=recipient,items=items,from=self.character and self.character.name} or nil
end
function N:CommitOutgoingMail()
 local m=self.outgoingMail; self.outgoingMail=nil
 if not m then return end
 local sent=self:SentMail()
 sent[#sent+1]={to=m.to,from=m.from,items=m.items,at=self:Now()}
 while #sent>100 do table.remove(sent,1) end
 self.dirty=true
end
function N:ClearSentMailTo(name,before)
 local k=key(name); if not k then return end
 local sent=self:SentMail()
 for i=#sent,1,-1 do
  local m=sent[i]
  if key(m.to)==k and (tonumber(m.at) or 0)<=(before or self:Now()) then table.remove(sent,i) end
 end
end
-- Sent mail still on its way: { to, items, at } with old ones dropped.
function N:MailInTransit()
 local sent=self:SentMail(); local out={}
 local cut=self:Now()-MAIL_DAYS*86400
 -- A newer mailbox read on the recipient (local or synced) means it arrived.
 local seen={}
 for _,c in pairs(self.db.characters) do local k=key(c.name); if k and c.mailAt then seen[k]=math.max(seen[k] or 0,c.mailAt) end end
 for i=#sent,1,-1 do
  local m=sent[i]
  if type(m)~='table' or (tonumber(m.at) or 0)<cut or (seen[key(m.to)] or 0)>=(tonumber(m.at) or 0) then table.remove(sent,i)
  else out[#out+1]=m end
 end
 return out
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
N:On('MAIL_SHOW',function() N.mailOpen=true; N:Later('mail',function() N:ScanMail() end) end)
N:On('MAIL_INBOX_UPDATE',function() if N.mailOpen then N:Later('mail',function() N:ScanMail() end) end end)
N:On('MAIL_CLOSED',function() N.mailOpen=false end)
N:On('MAIL_SEND_SUCCESS',function() N:CommitOutgoingMail() end)
N:On('MAIL_FAILED',function() N.outgoingMail=nil end)
N:On('PLAYER_EQUIPMENT_CHANGED',function() N:Later('equipped',function() N:ScanEquipped() end) end)
N:On('PLAYER_ENTERING_WORLD',function() N:ScanEquipped() end)
if hooksecurefunc and type(SendMail)=='function' then
 hooksecurefunc('SendMail',function(recipient) N:Guard('mailSend',function() N:CaptureOutgoingMail(recipient) end) end)
end
