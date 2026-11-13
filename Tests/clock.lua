local N,test,eq=...
-- 0.10.3: times saved while the PC clock was ahead.
test('Future timestamps (wrong PC clock) are pulled back to now instead of blocking sync',function()
 local now=N:Now()
 local c={name='Voidmark Bank',realm='TestRealm',faction='Horde',account='B2',at=now+50000,bags={},bank={},
  bagsAt=now+50000,bankAt=now-10,moneyAt=now+50000,money=5,
  professions={['Tailoring']={name='Tailoring',skill=1,max=75,at=now+50000,recipes={['1']={name='Bolt',learned=true,reagents={},at=now+50000}}}}}
 assert(not pcall(N.ValidateCharacter,N,N:Copy(c)),'rejected before the fix')
 eq(N:FixFutureTimes(c),5)
 eq(c.at,now);eq(c.bagsAt,now);eq(c.bankAt,now-10);eq(c.professions.Tailoring.at,now);eq(c.professions.Tailoring.recipes['1'].at,now)
 assert(N:ValidateCharacter(c))
 eq(N:FixFutureTimes(c),0)
end)
