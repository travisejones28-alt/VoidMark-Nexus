-- VoidMark Nexus help: FAQ and every command, opened from Settings or /vmn help.
local _, N = ...
-- Help window renderer. The same code ships in every VoidMark addon (one copy
-- per addon, own frame name), so each addon works on its own.
-- HELP = { title=..., intro=..., sections={ {title=..., commands={{'/cmd','what it does'},...}}
--                                            or {title=..., faq={{'Question?','Answer.'},...}} } }
local function HelpText(help,filter)
  filter=type(filter)=='string' and filter:lower():match('^%s*(.-)%s*$') or ''
  local function hit(...)
    if filter=='' then return true end
    for i=1,select('#',...) do
      local s=select(i,...)
      if type(s)=='string' and s:lower():find(filter,1,true) then return true end
    end
    return false
  end
  local out={}
  if filter=='' and help.intro then out[#out+1]=help.intro;out[#out+1]='' end
  local found=0
  for _,section in ipairs(help.sections or {}) do
    local lines={}
    for _,c in ipairs(section.commands or {}) do
      if hit(c[1],c[2],section.title) then lines[#lines+1]='|cffffd200'..c[1]..'|r  '..c[2];found=found+1 end
    end
    for _,q in ipairs(section.faq or {}) do
      if hit(q[1],q[2],section.title) then lines[#lines+1]='|cffffd200Q: '..q[1]..'|r';lines[#lines+1]='A: '..q[2];lines[#lines+1]='';found=found+1 end
    end
    if #lines>0 then
      out[#out+1]='|cffb86cff'..section.title:upper()..'|r'
      for _,l in ipairs(lines) do out[#out+1]=l end
      if lines[#lines]~='' then out[#out+1]='' end
    end
  end
  if found==0 then out[#out+1]='Nothing matches "'..filter..'".' end
  return table.concat(out,'\n'),found
end

local function HelpWindow(frameName,help)
  local w={help=help}
  local f,text,search
  local function render()
    if not f then return end
    local s=HelpText(help,search and search:GetText() or '')
    w.current=s
    text:SetText(s)
    local _,breaks=s:gsub('\n','\n')
    text:SetHeight(math.max(400,(breaks+1)*15+40))
  end
  local function build()
    f=CreateFrame('Frame',frameName,UIParent,BackdropTemplateMixin and 'BackdropTemplate' or nil)
    f:SetSize(580,620);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG')
    if f.SetToplevel then f:SetToplevel(true) end
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    f:EnableMouse(true);f:SetMovable(true);f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart',function() f:StartMoving() end)
    f:SetScript('OnDragStop',function() f:StopMovingOrSizing() end)
    if f.SetBackdrop then
      f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
      f:SetBackdropColor(.035,.025,.06,.97);f:SetBackdropBorderColor(.48,.25,.72,1)
    end
    local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
    title:SetPoint('TOPLEFT',16,-14);title:SetText(help.title or 'Help')
    local close=CreateFrame('Button',nil,f,'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT',-2,-2);close:SetScript('OnClick',function() f:Hide() end)
    local label=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    label:SetPoint('TOPLEFT',18,-48);label:SetText('Search:')
    search=CreateFrame('EditBox',frameName..'Search',f,'InputBoxTemplate')
    search:SetSize(220,20);search:SetPoint('TOPLEFT',70,-43)
    if search.SetAutoFocus then search:SetAutoFocus(false) end
    search:SetScript('OnTextChanged',function() render() end)
    search:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    search:SetScript('OnEnterPressed',function(self) self:ClearFocus() end)
    local hint=f:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
    hint:SetPoint('LEFT',search,'RIGHT',12,0);hint:SetText('Click the text, Ctrl+A, Ctrl+C to copy.')
    local scroll=CreateFrame('ScrollFrame',frameName..'Scroll',f,'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT',16,-72);scroll:SetPoint('BOTTOMRIGHT',-34,16)
    text=CreateFrame('EditBox',nil,scroll)
    if text.SetMultiLine then text:SetMultiLine(true) end
    if text.SetFontObject then text:SetFontObject(GameFontHighlight) end
    if text.SetAutoFocus then text:SetAutoFocus(false) end
    text:SetWidth(520)
    text:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    -- Read only: typing puts the help text back.
    text:SetScript('OnTextChanged',function(self,user) if user and w.current then self:SetText(w.current) end end)
    scroll:SetScrollChild(text)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=frameName end
    f:Hide()
  end
  function w.Open(filter)
    if not f then build() end
    if filter~=nil and search then search:SetText(filter) end
    render();f:Show()
    return f
  end
  function w.Toggle()
    if f and f:IsShown() then f:Hide() else w.Open() end
  end
  function w.Text(filter) return HelpText(help,filter) end
  function w.Frame() return f end
  return w
end

N.HELP={title='VoidMark Nexus: Help & commands',
 intro='Every command starts with /vmn. Open this window from Settings > Help & commands, or type /vmn help. Type in Search to filter.',
 sections={
 {title='Window and basics',commands={
  {'/vmn','Open or close the Nexus window.'},
  {'/vmn help [word]  (or /vmn faq, /vmn commands)','This window (FAQ and every command); a word searches it.'},
  {'/vmn resetwindow','Put the window back to its normal size, position and scale.'},
  {'/vmn debug','Diagnostics (copyable text).'},
  {'/vmn dash  (or /vmn dashboard)','Show or hide the small farming dashboard.'},
  {'/vmn notify on | off | reset','Rank-cap and route notices on or off; reset lets them show again.'},
  {'/vmn native','Use the normal game profession window.'}}},
 {title='Gathering routes',commands={
  {'/vmn route','Route options with a map preview; pick one and Start this route.'},
  {'/vmn route now  (or /vmn start now)','Start the balanced loop straight away.'},
  {'/vmn start','Same as /vmn route.'},
  {'/vmn stop','Stop the route.'},
  {'/vmn next  (or /vmn skip)','Skip to the next stop.'},
  {'/vmn pause','Pause or resume the route.'},
  {'/vmn rejoin','Rejoin the loop at the nearest stop.'},
  {'/vmn restart','Go back to stop 1.'},
  {'/vmn kind herb | ore | all','What to gather.'},
  {'/vmn target NAME','Only one herb or ore (no name: everything again).'},
  {'/vmn skillroute herb | ore','Loop of nodes that still give skill-ups.'},
  {'/vmn grey  (or /vmn gray)','Hide or show resources that give no skill-ups.'},
  {'/vmn arrowscale NUMBER','Arrow size.'},
  {'/vmn cancelplan','Cancel a route calculation in progress.'},
  {'/vmn mapcontrols [reset]  (or /vmn mapfilters)','World-map filter menu; reset moves its button back.'},
  {'/vmn pools on | off','Fishing pool markers on the world map.'}}},
 {title='Learning and results',commands={
  {'/vmn routes [zone]','Compare the routes you have run, best first.'},
  {'/vmn runroute N','Run route N from that list again.'},
  {'/vmn routereset N | current | zone | all','Forget learned performance (sessions and other zones are kept).'},
  {'/vmn routelog','History of the route options you picked.'},
  {'/vmn laps','This lap and the last lap.'},
  {'/vmn spots [forget | forget all]','Spots learned as often empty; forget them here or everywhere.'},
  {'/vmn terrain on | off | use | ignore | clear','Trail learning; whether loops use trails; erase trails.'},
  {'/vmn block [yards]','Mark an obstacle where you stand (default size if no number).'},
  {'/vmn clearblocks','Remove obstacle marks in this zone.'}}},
 {title='Gold and prices',commands={
  {'/vmn compare','Herbs vs ore here: nodes/hr and gold/hr.'},
  {'/vmn prices','Prices of resources here with age, confidence and stale flags.'},
  {'/vmn market ITEM','Open an item in VoidMark Market (read only).'},
  {'/vmn price ITEM_ID GOLD','Set your own price for an item.'},
  {'/vmn gold  (or /vmn money)','Gold on every character and the total.'}}},
 {title='Professions and items',commands={
  {'/vmn level PROFESSION [target]','Next leveling step and the methods compared.'},
  {'/vmn levelshop','Shopping list and what to collect from each character.'},
  {'/vmn transfers','What to mail between characters for queued crafts.'},
  {'/vmn find NAME  (or /vmn search)','Who holds an item (also: a, b, c / all / herbs / ore / leather / cloth / enchanting).'},
  {'/vmn need lw | alch  (or /vmn have)','Materials needed for a profession, or e.g. 414 light leather.'},
  {'/vmn cd  (or /vmn cooldowns)','Profession cooldowns on every character.'},
  {'/vmn missing [profession]','Recipes you have not learned yet and where to get them (also Professions > To learn, or the MR button on the profession window).'},
  {'/vmn exportrecipes','Copy the recipe sources you recorded, for the other account (also Characters > Export).'},
  {'/vmn importrecipes','Paste recipe sources from the other account. Your own records are kept.'}}},
 {title='Skinning and fishing',commands={
  {'/vmn skinning','Skinning page: beast levels, zones, your spots, leather.'},
  {'/vmn fishing','Fishing guide with your catches and pools.'},
  {'/vmn pool NAME','Mark a fishing pool where you stand.'},
  {'/vmn poolroute','Loop through this zone\'s known pools.'}}},
 {title='Two accounts',commands={
  {'/vmn pair First Surname','Pair with your other account\'s character (do it on both).'},
  {'/vmn unpair NAME','Stop syncing with that character.'},
  {'/vmn sync','Sync status: last sync, offline, stale data.'},
  {'/vmn sync now','Ask for a sync right now.'},
  {'/vmn export  /  /vmn import','Copy data between accounts by hand (works offline).'}}},
 {title='FAQ',faq={
  {'How do I start gathering?','Gather page > pick Herbs, Ore or one resource > Start route. Pick an option in the preview and press Start this route. The arrow takes you stop to stop and moves on when you gather or get close.'},
  {'What do cyan and purple route lines mean?','Cyan legs follow paths you have walked before (verified). Purple legs are estimates. Walk a leg a couple of times and it turns cyan next time.'},
  {'The route goes through a wall or cliff. What do I do?','Stand next to it and type /vmn block 60. New loops go around the mark. /vmn clearblocks removes marks.'},
  {'How does Nexus learn which routes are best?','Each loop keeps its own laps, finds, empty stops, items and time. Options are ranked by what you really got; a lap or two only nudges the estimate. /vmn routes shows them.'},
  {'Why does gold/hr say unknown or show a *?','Some resources have no price. Nexus never counts a missing price as zero. Scan the auction house with VoidMark Market or set a price with /vmn price.'},
  {'Will Nexus buy or post auctions?','No. It only reads VoidMark Market prices. /vmn market only opens the item in Market.'},
  {'How do I sync with my bank character?','Log both in, then on each type /vmn pair with the other character\'s full name. It syncs by itself whenever both are online. /vmn sync shows the status.'},
  {'Why is a character marked STALE?','Its bags or bank were not seen recently. Log into it (or let it sync) and open the bank once.'},
  {'How do I see what to craft next?','Professions > pick the profession > Level up. The top line says what to craft now and how many your bags allow. /vmn level does the same in chat.'},
  {'How do I resize the window?','Drag the bottom-right corner. The size is kept. /vmn resetwindow restores it.'},
  {'A fishing pool was not recorded.','Stand by it and type /vmn pool NAME. Nexus only records pools the game identifies.'},
  {'Spawn spots on the map are not guaranteed nodes, right?','Right. They are places nodes can spawn. Nexus learns which spots are often empty and skips them.'}}}}}
N.helpWindow=HelpWindow('VoidMarkNexusHelp',N.HELP)
function N:ShowHelp(filter) return self.helpWindow.Open(filter) end
