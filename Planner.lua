local _, N = ...
local function seconds() return GetTime and GetTime() or time() end

function N:PlannerCacheKey(value)
 local function encode(v)
  if type(v)~='table' then local s=tostring(v);return type(v)..#s..':'..s end
  local keys={};for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b) return type(a)..tostring(a)<type(b)..tostring(b) end)
  local parts={'{'};for _,k in ipairs(keys) do parts[#parts+1]=encode(k)..encode(v[k]) end
  parts[#parts+1]='}';return table.concat(parts)
 end
 return encode(value)
end
local function validResult(self,route)
 if type(route)~='table' then return false end
 if route.points then return self:CleanNavigationRoute(route)~=nil end
 if #route>5 then return false end
 for _,entry in ipairs(route) do
  if type(entry)~='table' or not self:Finite(entry.map,1,100000)
   or type(entry.name)~='string' or not self:CleanNavigationRoute(entry.route) then return false end
  if entry.alternatives then
   if type(entry.alternatives)~='table' or #entry.alternatives>5 then return false end
   for _,r in ipairs(entry.alternatives) do if not self:CleanNavigationRoute(r) then return false end end
  end
 end
 return true
end
function N:GetPlannerCache(key)
 if self.cacheReadOnly then return end
 local entries=self.db.calculations.routes
 for i,entry in ipairs(entries) do
  if entry.key==key and self:Finite(entry.at,0,self:Now()) and self:Now()-entry.at<=604800
   and validResult(self,entry.route) then
   table.remove(entries,i);table.insert(entries,1,entry)
   if self.planningJob then self.planningJob.cached=true end
   self.cacheStats.routes=self.cacheStats.routes+1
   return self:Copy(entry.route)
  end
 end
 self.cacheStats.misses=self.cacheStats.misses+1
end
function N:PutPlannerCache(key,route)
 if self.cacheReadOnly or type(key)~='string' or #key>200000 then return end
 local copy=self:PortableCache(route)
 if not copy or not validResult(self,copy) then return end
 local entries=self.db.calculations.routes
 for i=#entries,1,-1 do if entries[i].key==key then table.remove(entries,i) end end
 table.insert(entries,1,{key=key,route=copy,at=self:Now()})
 self:PruneCalculationCache()
end
function N:SetPlannerProgress(stage,done,total)
 local job=self.planningJob;if not job then return end
 job.stage=stage
 if done then job.done,job.total=done,total end
end
function N:PlannerStatus()
 local job=self.planningJob;if not job then return '' end
 local elapsed=math.max(0,seconds()-job.started)
 local count=job.total and string.format(' | %d / %d',job.done or 0,job.total) or ''
 local eta=''
 if job.done and job.done>0 and job.total>job.done then
  eta=string.format(' | ~%ds left',math.ceil(elapsed*(job.total-job.done)/job.done))
 end
 return string.format('%s%s\nElapsed %ds%s',job.stage or 'Starting',count,elapsed,eta)
end
function N:ShowPlannerStatus()
 if not self.plannerWindow then
  local f=CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
  f:SetSize(380,100);f:SetPoint('CENTER',UIParent,'CENTER',0,160);f:SetFrameStrata('DIALOG')
  f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
  f:SetBackdropColor(.025,.015,.04,.96);f:SetBackdropBorderColor(.55,.25,.85,1)
  local title=f:CreateFontString(nil,'OVERLAY','GameFontNormal')
  title:SetPoint('TOPLEFT',12,-10);title:SetText('VoidMark Nexus | Planning')
  f.status=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  f.status:SetPoint('TOPLEFT',12,-32);f.status:SetPoint('TOPRIGHT',-12,-32)
  local cancel=CreateFrame('Button',nil,f,'UIPanelButtonTemplate')
  cancel:SetSize(80,22);cancel:SetPoint('BOTTOMRIGHT',-10,8);cancel:SetText('Cancel')
  cancel:SetScript('OnClick',function() N:CancelPlanner('Route calculation cancelled.') end)
  self.plannerWindow=f
 end
 self.plannerWindow.status:SetText(self:PlannerStatus());self.plannerWindow:Show()
end
function N:CancelPlanner(message)
 local wasRunning=self.planningThread~=nil
 self.planningThread,self.planningJob=nil,nil
 if self.plannerWindow then self.plannerWindow:Hide() end
 if message and wasRunning then self:Print(message) end
end
function N:PlannerCheckpoint()
 if not self.planningThread or coroutine.running()~=self.planningThread then return end
 self.planningWork=(self.planningWork or 0)+1
 local clock=type(debugprofilestop)=='function' and debugprofilestop() or nil
 if self.planningWork>=2500 or (clock and self.planningClock and clock-self.planningClock>=3) then
  coroutine.yield();self.planningWork=0;self.planningClock=type(debugprofilestop)=='function' and debugprofilestop() or nil
 end
end
function N:RunPlanner(work,complete)
 if self.planningThread then self:ShowPlannerStatus();return self:Print('A route calculation is already running. /vmn cancelplan to cancel.') end
 if self:Call(InCombatLockdown) then return self:Print('Plan routes outside combat.') end
 self.planningJob={started=seconds(),stage='Starting'}
 local thread=coroutine.create(work);self.planningThread=thread;self.planningWork=0
 self:ShowPlannerStatus()
 local function step()
  if self.planningThread~=thread then return end
  if self:Call(InCombatLockdown) then self:CancelPlanner('Route calculation cancelled by combat.');return end
  if seconds()-self.planningJob.started>=30 then
   local best=self.planningJob.best
   if best and self.planningJob.cacheKey then
    best.bestSoFar=true;self:PutPlannerCache(self.planningJob.cacheKey,best)
   end
   self:CancelPlanner()
   if best then self:Print('30-second limit reached; using the best completed circuit so far.');self:Guard('route result',complete,best)
   else self:Print('Calculation stopped after 30 seconds. Try Start Here or narrower resource filters.') end
   return
  end
  self.planningClock=type(debugprofilestop)=='function' and debugprofilestop() or nil
  local ok,value=coroutine.resume(thread)
  if not ok then self:CancelPlanner();self:Error('route calculation',value);return end
  if coroutine.status(thread)=='dead' then
   local elapsed=seconds()-self.planningJob.started
   local cached=self.planningJob.cached
   self:CancelPlanner();self:Print(string.format('Route calculation finished in %.1fs%s.',elapsed,cached and ' (reused saved result)' or ''))
   self:Guard('route result',complete,value)
  elseif C_Timer and C_Timer.After then
   self:ShowPlannerStatus();C_Timer.After(0,step)
  else self:CancelPlanner('Incremental route calculation requires client timers.') end
 end
 step()
end
