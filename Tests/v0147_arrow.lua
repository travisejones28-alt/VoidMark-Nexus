local N,test,eq=...
test('0.14.7 Arrow: starting a route turns a hidden arrow back on',function()
 local s=N.db.settings; local vis=s.routeVisible
 s.routeVisible=false
 N:StartRoute({map=1411,width=5000,height=3000,speed=7,points={{x=.45,y=.4,name='A'}}},true)
 eq(s.routeVisible,true)
 N:UpdateArrow(); assert(N.arrow:IsShown(),'arrow shown after start')
 N:StopRoute(); s.routeVisible=vis
end)
test('0.14.7 Arrow: points on the route zone while the game reports a smaller sub-map',function()
 local best,pos=C_Map.GetBestMapForUnit,C_Map.GetPlayerMapPosition
 C_Map.GetBestMapForUnit=function() return 9999 end -- cave / town map
 C_Map.GetPlayerMapPosition=function(map) if map==1411 then return {GetXY=function() return .4,.4 end} end return {GetXY=function() return .5,.5 end} end
 N.db.settings.routeVisible=true
 N:StartRoute({map=1411,width=5000,height=3000,speed=10,points={{x=.45,y=.4,name='Peacebloom'}}},true)
 N:UpdateArrow()
 eq(N.arrow.status.text,'Peacebloom'); eq(N.arrow.label.text,'250 yd'); assert(N.arrow.bearing,'arrow has a bearing')
 -- Really in another zone: still says where to go.
 C_Map.GetPlayerMapPosition=function(map) if map==1411 then return nil end return {GetXY=function() return .5,.5 end} end
 N:UpdateArrow(); eq(N.arrow.status.text:sub(1,6),'Go to ')
 C_Map.GetBestMapForUnit,C_Map.GetPlayerMapPosition=best,pos; N:StopRoute()
end)
test('0.14.7 Arrow: a saved spot off the screen falls back to the default spot',function()
 local s=N.db.settings; local keep=s.arrowPosition
 s.arrowPosition={point='TOP',relativePoint='TOP',x=5000,y=-8000}
 N:RestoreArrowPosition(); eq(N.arrow.anchor[1],'TOP'); eq(N.arrow.anchor[4],0); eq(N.arrow.anchor[5],-135)
 s.arrowPosition={point='TOP',relativePoint='TOP',x=40,y=-200}
 N:RestoreArrowPosition(); eq(N.arrow.anchor[4],40); eq(N.arrow.anchor[5],-200)
 s.arrowPosition=keep
end)
