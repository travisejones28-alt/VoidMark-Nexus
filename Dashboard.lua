local _, N = ...
-- 0.11 farming dashboard, gentle notifications, and a read-only API.
--
-- Dashboard (/vmn dash): a small window with this session's time, resources,
-- gathering skill gained, value, nodes/hour, gold/hour, the current route's
-- expected versus actual rate, and how this session compares with your last
-- ten. Values use current prices; unpriced items are listed, never zero.
-- Notifications: one chat line when a profession is 5 points from its rank cap
-- (and once at the cap), and once per route when stops need more skill than you
-- have. Each is said once per rank/route; /vmn notify off silences them.
local floor=math.floor

--------------------------------------------------------------------------------
-- Session figures
--------------------------------------------------------------------------------
-- Skill gained this session in Herbalism/Mining/Skinning/Fishing.
local function gatherSkills(self)
 local out={}
 for pid,p in pairs(self.character and self.character.professions or {}) do
  local name=type(p)=='table' and p.name
  if name=='Herbalism' or name=='Mining' or name=='Skinning' or name=='Fishing' then out[name]=tonumber(p.skill) end
 end
 return out
end
do
 local start=N.StartSession
 N.StartSession=function(self,...)
  local a,b=start(self,...)
  if self.session then self.session.skillStart=gatherSkills(self);self.session.nodes=0 end
  return a,b
 end
end
N:On('UNIT_SPELLCAST_SUCCEEDED',function(unit,_,spell)
 local kind=unit=='player' and N.gatherSpells and N.gatherSpells[spell]
 if not kind or kind=='fish' then return end
 if not N.session then N:StartSession() end
 N.session.nodes=(N.session.nodes or 0)+1
end)
function N:DashboardStats(session)
 session=session or self.session
 if not session then return nil end
 local secs=math.max(1,(session.finished or self:Now())-(session.started or self:Now()))
 local hours=secs/3600
 local value,unpriced,stale,total=self:ItemsValue(session.items)
 local gained=0
 if type(session.skillStart)=='table' and not session.finished then
  for name,v in pairs(gatherSkills(self)) do local s=session.skillStart[name];if s and v then gained=gained+math.max(0,v-s) end end
 end
 return {seconds=secs,total=session.total or total,nodes=session.nodes,value=value,unpriced=unpriced,stale=stale,
  gold=(total>0 and unpriced<total) and value/hours or nil,nodesPerHour=session.nodes and session.nodes/hours or nil,
  itemsPerHour=(session.total or total)/hours,skill=gained}
end
-- Averages over your last saved sessions (at least 5 minutes long).
function N:PreviousSessionAverages(limit)
 local n,gold,goldN,items,hours=0,0,0,0,0
 for i=#self.db.sessions,1,-1 do
  local s=self.db.sessions[i]
  if type(s)=='table' and s.started and s.finished and s.finished-s.started>=300 then
   local st=self:DashboardStats(s)
   if st then
    n=n+1;items=items+st.total;hours=hours+st.seconds/3600
    if st.gold then gold=gold+st.gold;goldN=goldN+1 end
   end
   if n>=(limit or 10) then break end
  end
 end
 if n==0 then return nil end
 return {count=n,itemsPerHour=hours>0 and items/hours or 0,gold=goldN>0 and gold/goldN or nil}
end
function N:DashboardLines()
 local st=self:DashboardStats()
 local lines={}
 if not st then return {'No gathering this session yet.'} end
 lines[#lines+1]=string.format('Session %d min: %d items%s',floor(st.seconds/60),st.total,st.skill>0 and ('  +'..st.skill..' skill') or '')
 lines[#lines+1]=string.format('%s%.0f items/hr  %s',st.nodesPerHour and string.format('%.0f nodes/hr  ',st.nodesPerHour) or '',st.itemsPerHour,
  st.gold and (self:Gold(st.gold)..'/hr') or 'gold/hr unknown')
 lines[#lines+1]='Value: '..self:Money(st.value)..(st.unpriced>0 and (' + '..st.unpriced..' unpriced') or '')..(st.stale and ' (some prices stale)' or '')
 local route=self.activeRoute
 if route and route.loop and self.ScoreRoute then
  local s=self:ScoreRoute(route,route.variant)
  local lap=self.lapStats
  local now=lap and lap.started and self:Now()-lap.started>=60 and lap.picked/((self:Now()-lap.started)/3600)
  lines[#lines+1]=string.format('Route: expect %d/hr%s [%s]',floor(s.rate+.5),now and string.format(', this lap %d/hr',floor(now+.5)) or '',s.confidence)
 end
 local prev=self:PreviousSessionAverages(10)
 if prev then
  lines[#lines+1]=string.format('Last %d sessions: %.0f items/hr%s',prev.count,prev.itemsPerHour,prev.gold and (', '..self:Gold(prev.gold)..'/hr') or '')
 end
 return lines
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
function N:CreateDashboard()
 if self.dashboard then return self.dashboard end
 local f=CreateFrame('Frame','VoidMarkNexusDashboard',UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
 f:SetSize(270,104);f:SetFrameStrata('MEDIUM');f:SetClampedToScreen(true)
 f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
 if f.SetBackdrop then
  f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
  f:SetBackdropColor(.035,.025,.06,.85);f:SetBackdropBorderColor(.48,.25,.72,1)
 end
 local pos=self.db.settings.dashPosition
 if type(pos)=='table' and self:Finite(pos[1],-20000,20000) and self:Finite(pos[2],-20000,20000) then f:SetPoint('CENTER',UIParent,'CENTER',pos[1],pos[2])
 else f:SetPoint('TOPRIGHT',UIParent,'TOPRIGHT',-220,-220) end
 f:SetScript('OnDragStart',function() f:StartMoving() end)
 f:SetScript('OnDragStop',function()
  f:StopMovingOrSizing()
  local x,y=f:GetCenter();local ux,uy=UIParent:GetCenter()
  if x and ux then N.db.settings.dashPosition={x-ux,y-uy} end
 end)
 f.text=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 f.text:SetPoint('TOPLEFT',8,-8);f.text:SetWidth(254);f.text:SetJustifyH('LEFT')
 local close=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');close:SetSize(18,18);close:SetPoint('TOPRIGHT',-3,-3);close:SetText('x')
 close:SetScript('OnClick',function() N:ToggleDashboard(false) end)
 local elapsed=1
 f:SetScript('OnUpdate',function(_,dt) elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0;N:Guard('dashboard',function() N:UpdateDashboard() end) end)
 self.dashboard=f
 return f
end
function N:UpdateDashboard()
 local f=self.dashboard;if not f or not f:IsShown() then return end
 local lines=self:DashboardLines()
 f.text:SetText(table.concat(lines,'\n'))
 f:SetHeight(16+#lines*13)
end
function N:ToggleDashboard(show)
 if show==nil then show=not (self.dashboard and self.dashboard:IsShown()) end
 self.db.settings.dashboard=show and true or false
 if show then self:CreateDashboard():Show();self:UpdateDashboard() elseif self.dashboard then self.dashboard:Hide() end
end
N:On('PLAYER_ENTERING_WORLD',function() if N.db.settings.dashboard then N:ToggleDashboard(true) end end)

--------------------------------------------------------------------------------
-- Notifications
--------------------------------------------------------------------------------
function N:Notify(key,text)
 if self.db.settings.notify==false then return false end
 self.db.notified=type(self.db.notified)=='table' and self.db.notified or {}
 if self.db.notified[key] then return false end
 local n=0;for _ in pairs(self.db.notified) do n=n+1 end
 if n>300 then self.db.notified={} end
 self.db.notified[key]=self:Now()
 self:Print(text)
 return true
end
function N:CheckRankCaps()
 for pid,p in pairs(self.character and self.character.professions or {}) do
  if type(p)=='table' and self:Finite(p.skill,1,1000) and self:Finite(p.max,1,1000) and p.max<300 then
   local who=self.character.name or ''
   if p.skill>=p.max then
    self:Notify('cap:'..who..':'..tostring(pid)..':'..p.max,string.format('%s %d/%d: rank cap reached. Train the next rank to keep gaining skill.',p.name or 'Profession',p.skill,p.max))
   elseif p.skill>=p.max-5 then
    self:Notify('near:'..who..':'..tostring(pid)..':'..p.max,string.format('%s %d/%d: %d points to the rank cap. Plan a trainer visit.',p.name or 'Profession',p.skill,p.max,p.max-p.skill))
   end
  end
 end
end
function N:CheckRouteRequirements(route)
 if not route or not route.points or route.skillup then return end
 local skills=self:GatheringSkills();local blocked=0
 for _,p in ipairs(route.points) do
  local name=p.name and (p.name:match('^(.-) %+%d+$') or p.name)
  for _,kind in pairs(self.nodeTypes) do
   if kind.name==name then
    local s=skills[kind.kind]
    if s and self:Finite(kind.skill,1,1000) and s.skill<kind.skill then blocked=blocked+1 end
    break
   end
  end
 end
 if blocked>0 and self.RouteKey then
  self:Notify('req:'..tostring(self:RouteKey(route)),blocked..' stop'..(blocked==1 and '' or 's')..' on this route need more gathering skill than you have; they will be visited but you cannot gather them.')
 end
end
do
 local scan=N.ScanProfessions
 N.ScanProfessions=function(self,...)
  local a,b,c=scan(self,...)
  if not self.generating then self:Guard('notify',function() self:CheckRankCaps() end) end
  return a,b,c
 end
 local start=N.StartRoute
 N.StartRoute=function(self,route,...)
  local a,b=start(self,route,...)
  self:Guard('notify',function() self:CheckRouteRequirements(route) end)
  return a,b
 end
end

--------------------------------------------------------------------------------
-- Read-only API for other VoidMark addons (Journey can read gathering figures
-- without Nexus depending on it). Returns copies; never changes saved data.
--------------------------------------------------------------------------------
N.API={version=1}
function N.API.GetSessionStats() local st=N.ready and N:DashboardStats();return st and N:Copy(st) or nil end
function N.API.GetGatheringSkills() return N.ready and N:Copy(N:GatheringSkills()) or nil end
function N.API.GetBestRoutes(limit)
 if not N.ready or not N.BestRouteRecords then return nil end
 local out={}
 for _,e in ipairs(N:BestRouteRecords(nil,limit or 5)) do
  out[#out+1]={zone=N:RouteZoneName(e.r.map),map=e.r.map,laps=e.r.laps,nodesPerHour=e.rate,goldPerHour=e.gold}
 end
 return out
end

N:AddCommand('dash',function(self) self:ToggleDashboard() end,'/vmn dash (farming dashboard), /vmn notify on|off')
N:AddCommand('dashboard',function(self) self:ToggleDashboard() end)
N:AddCommand('notify',function(self,args)
 if args=='off' then self.db.settings.notify=false elseif args=='on' then self.db.settings.notify=true
 elseif args=='reset' then self.db.notified={} end
 self:Print('Notifications '..(self.db.settings.notify==false and 'off' or 'on')..'. /vmn notify on|off|reset')
end)
