local N,test,eq,widget,root=...
-- Help window: every slash command the addon handles is listed.
local function read(path) local f=assert(io.open(path,'r')); local s=f:read('*a'); f:close(); return s end
test('Help: every /vmn command is in the Help window',function()
 local words={}
 local boot=read(root..'/Boot.lua')
 local slash=boot:match('function N:Slash%(msg%)(.-)\nend\n')
 assert(slash,'Slash handler found')
 for w in slash:gmatch("command==%'([%w]+)%'") do words[w]=true end
 for _,f in ipairs({'RouteTerrain','RouteLearning','LevelingPlus','WildGather','Interface','Dashboard'}) do
  for w in read(root..'/'..f..'.lua'):gmatch("AddCommand%(%'([%w]+)%'") do words[w]=true end
 end
 local text=N.helpWindow.Text()
 local missing={}
 for w in pairs(words) do if not text:find('/vmn '..w,1,true) then missing[#missing+1]=w end end
 table.sort(missing)
 eq(table.concat(missing,', '),'')
 assert(next(words),'commands found')
end)
test('Help: opens from Settings and /vmn help, and search filters it',function()
 N:Show('Settings')
 N.ui.helpButton.scripts.OnClick()
 local f=N.helpWindow.Frame(); assert(f and f:IsShown())
 N:Slash('help sync')
 local text,found=N.helpWindow.Text('sync'); assert(found>0 and text:find('/vmn sync',1,true)); assert(not text:find('/vmn poolroute',1,true))
 local _,none=N.helpWindow.Text('zzzz-nothing'); eq(none,0)
 eq(#N.errors,0)
end)
