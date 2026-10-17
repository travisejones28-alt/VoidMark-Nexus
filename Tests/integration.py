"""Load the four real addons together in a shared mocked Lua 5.1 UI.

Requires lupa==2.8 and peer source checkouts. This checks API/handler contracts,
not rendering, secure-frame behavior, or the game's actual focus manager.
"""
from pathlib import Path
import argparse
import os
import runpy
import lupa.lua51

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--mini', type=Path, required=True)
parser.add_argument('--forever', type=Path, required=True)
parser.add_argument('--market', type=Path, required=True)
args = parser.parse_args()
paths = {key: value.resolve() for key, value in vars(args).items()}
paths['nexus'] = Path(__file__).resolve().parents[1]
original = lupa.lua51.LuaRuntime


def guarded(*a, **kw):
    runtime = original(*a, **kw)
    runtime.execute("local n=0;debug.sethook(function() n=n+1;if n>20000 then error('Integration instruction limit') end end,'',10000)")
    return runtime


lupa.lua51.LuaRuntime = guarded
host = (paths['mini'] / 'tests/smoke.lua').read_text(encoding='utf-8').split('UIParent=CreateFrame')[0]
host += r'''
setmetatable(Methods,{__index=function(_,key)
 for _,prefix in ipairs({'Set','Get','Enable','Disable','Register','Unregister','Clear','Start','Stop'}) do
  if key:sub(1,#prefix)==prefix then return function() end end
 end
end})
function Methods:RegisterEvent(e) self.events=self.events or {};self.events[e]=true end
function Methods:SetToplevel(v) self.toplevel=v end
function Methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or 'MEDIUM' end
function Methods:GetStringHeight() return 450 end
function Methods:GetStringWidth() return #(self.text or '')*6 end
UIParent=CreateFrame('Frame','UIParent');UIParent:SetSize(1920,1080)
Minimap=CreateFrame('Minimap','Minimap',UIParent);Minimap:SetSize(140,140)
MinimapCluster=CreateFrame('Frame','MinimapCluster',UIParent)
GameTimeFrame=CreateFrame('Button','GameTimeFrame',MinimapCluster)
GameTooltip=CreateFrame('Frame','GameTooltip',UIParent)
local lib=LibStub
LibStub=function(name,silent) if name=='LibDBIcon-1.0' then return nil end return lib(name,silent) end
C_Map={GetBestMapForUnit=function() return 1431 end,
 GetPlayerMapPosition=function() return {GetXY=function() return .4,.4 end} end,
 GetMapWorldSize=function() return 5000,3000 end}
C_Minimap={GetViewRadius=function() return 100 end}
C_AuctionHouse={}
local profileMS=0
function debugprofilestop() profileMS=profileMS+.01;return profileMS end
function GetMinimapZoneText() return 'Duskwood' end
function GetPlayerFacing() return 0 end
function GetCVarBool() return false end
function GetFramerate() return 60 end
function GetMoney() return 1000000 end
function GetNormalizedRealmName() return 'TestRealm' end
function GetCursorPosition() return 900,500 end
INTEGRATION_FRAMES=frames
function IntegrationEvent(event,...)
 for _,frame in ipairs(frames) do
  if frame.events and frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame,event,...) end
 end
end
'''

for order in [('market', 'nexus', 'mini'), ('market', 'mini', 'nexus')]:
    # Boot the complete Forever addon and run its existing regressions first.
    os.chdir(paths['forever'])
    state = runpy.run_path(str(paths['forever'] / 'tests/validate.py'))
    runtime = state['LUA']
    runtime.execute(host)
    namespaces = {}
    for name in order:
        root = paths[name] / ('VoidMarkNexus' if name == 'nexus' else '')
        toc = root / {'market': 'VoidMarkMarket.toc', 'mini': 'VoidMarkMiniMap.toc', 'nexus': 'VoidMarkNexus.toc'}[name]
        namespace = runtime.table()
        namespaces[name] = namespace
        for line in toc.read_text(encoding='utf-8').splitlines():
            if line.strip().endswith('.lua') and not line.startswith('#'):
                runtime.globals().INTEGRATION_FILE = str(root / line.strip().replace('\\', '/'))
                runtime.globals().INTEGRATION_NS = namespace
                runtime.execute("assert(loadfile(INTEGRATION_FILE))('" + toc.stem + "',INTEGRATION_NS)")
    runtime.execute(r'''
IntegrationEvent('ADDON_LOADED','VoidMarkMarket')
IntegrationEvent('ADDON_LOADED','VoidMarkNexus')
IntegrationEvent('PLAYER_LOGIN')
local N,M=VoidMarkNexus,VoidMarkMarket
assert(N.ready and M.db)
M.db.market[765]={itemID=765,itemSuffix=0,fairValue=250,lastSeen=time(),latest={median=250,at=time()}}
local price=N:Price(765)
assert(price and price.unit==250 and price.source=='VoidMark Market','Real Market bridge did not use the matching economy')
VoidMarkMarketDB.economies['ForeignRealm|Horde']={market={[766]={fairValue=999999,lastSeen=time(),latest={median=999999}}}}
assert(N:Price(766)==nil,'Foreign economy contaminated recipe pricing')
assert(not M.window:IsShown(),'Market must remain closed on login')
local controller
for _,f in ipairs(INTEGRATION_FRAMES) do if f.events and f.events.PLAYER_REGEN_DISABLED then controller=f end end
assert(controller)
controller.scripts.OnUpdate(controller,2)
local click=N.minimap:GetScript('OnClick');assert(type(click)=='function')
click(N.minimap,'LeftButton')
assert(N.ui.frame:IsShown(),'Collected Nexus icon lost its real click handler')
M:SetView('market');assert(M.window:IsShown())
assert(N.ui.frame:GetFrameStrata()=='MEDIUM' and M.window:GetFrameStrata()=='MEDIUM')
assert(N.ui.frame.toplevel and M.window.toplevel,'Normal panels must participate in focus raising')
assert(VoidMark.MainWindow:GetFrameStrata()=='LOW')
assert(VoidMark.MainWindow.TitleBar:GetFrameStrata()=='LOW')
assert(Minimap:GetFrameStrata()=='BACKGROUND')
assert(N.minimap:GetFrameStrata()=='BACKGROUND','Collected Nexus icon floats over normal windows')
assert(SLASH_VOIDMARKMARKET1=='/vmm' and SLASH_VOIDMARKMINIMAP1=='/vmini')
assert(SLASH_VOIDMARKMINIMAP3==nil,'Duplicate /vmm alias still registered')
N.activeRoute={map=1431,width=5000,height=3000,speed=7,origin={x=.4,y=.4},points={{x=.405,y=.4}}}
N.waypoint=1;N.routePaused=false;N:ShowArrow();N:UpdateArrow();N:UpdateMinimapRoute()
assert(N.arrow:GetFrameStrata()=='LOW' and N.arrow:GetScript('OnEnter')==nil)
assert(N.minimapRouteOverlay:GetFrameStrata()=='BACKGROUND')
assert(#N.errors==0,table.concat(N.errors,'\n'))
assert(not GameTimeFrame:IsShown(),'Native calendar/daylight chrome reappeared')
print('PASS: shared real-addon UI, collected icon clicks, startup visibility, unique commands and layering')
''')
    print('PASS integration load order:', ' -> '.join(order), flush=True)
