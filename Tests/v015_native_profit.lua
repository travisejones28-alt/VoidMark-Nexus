local N,test,eq,widget=...
test('0.15.0 Profit shows in the game profession window rows and detail',function()
 local pid=N:ProfessionKey('Tailoring','Tailoring')
 local c=N.character; c.professions[pid]={name='Tailoring',skill=150,max=150,at=N:Now(),recipes={
  ['1']={name='Heavy Woolen Cloak',learned=true,output=4311,outputMin=1,outputMax=1,reagents={{id=2997,qty=3},{id=2321,qty=2}}}}}
 N.activeProfession=pid
 local price=N.Price
 N.Price=function(_,id) local t={[2997]=100,[2321]=10,[4311]=1000}; return t[id] and {unit=t[id],at=N:Now(),stale=false} or nil end
 local names={[1]={'Cloaks','header'},[2]={'Heavy Woolen Cloak','easy'},[3]={'Unknown Thing','easy'}}
 GetTradeSkillInfo=function(i) local n=names[i]; if n then return n[1],n[2] end end
 GetTradeSkillNumReagents=function() return 2 end
 GetTradeSkillSelectionIndex=function() return 2 end
 TRADE_SKILLS_DISPLAYED=3
 for i=1,3 do local b=widget(); b.GetID=function() return i end; _G['TradeSkillSkill'..i]=b end
 TradeSkillDetailScrollChildFrame=widget(); TradeSkillReagent2=widget()
 local hooks={}; hooksecurefunc=function(name,fn) hooks[name]=fn end
 TradeSkillFrame_Update=function() end; TradeSkillFrame_SetSelection=function() end
 N.db.settings.nativeProfit=true; N.nativeProfitHooked=nil
 N:HookNativeProfit(); assert(hooks.TradeSkillFrame_Update and hooks.TradeSkillFrame_SetSelection,'hooks')
 hooks.TradeSkillFrame_Update()
 eq(TradeSkillSkill1.vmnProfit.text,'')
 -- cost 3*100+2*10=320; net 1000*0.95=950; profit 630
 assert(TradeSkillSkill2.vmnProfit.text:find('+6s 30c',1,true),'row: '..TradeSkillSkill2.vmnProfit.text)
 eq(TradeSkillSkill3.vmnProfit.text,'')
 local d=N.nativeDetail.text
 assert(d:find('Cost to craft: 0g 3s 20c',1,true) and d:find('Net profit:',1,true) and d:find('0g 6s 30c',1,true),'detail: '..d)
 N.db.settings.nativeProfit=false; N:UpdateNativeRows(); N:UpdateNativeDetail(); eq(TradeSkillSkill2.vmnProfit.text,''); eq(N.nativeDetail.text,'')
 N.db.settings.nativeProfit=true; N.Price=price
 for i=1,3 do _G['TradeSkillSkill'..i]=nil end
 TradeSkillDetailScrollChildFrame=nil; TradeSkillReagent2=nil; TradeSkillFrame_Update=nil; TradeSkillFrame_SetSelection=nil; hooksecurefunc=nil
 GetTradeSkillInfo=nil; GetTradeSkillNumReagents=nil; GetTradeSkillSelectionIndex=nil; N.activeProfession=nil; c.professions[pid]=nil
end)
