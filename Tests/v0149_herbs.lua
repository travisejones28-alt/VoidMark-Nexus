local N,test,eq=...
test('0.14.9 Herbs: Wowhead Forever herb spots are loaded',function()
 assert((N.extraWowheadHerbSpots or 0)>=600,'expected ~650 added herb spots, got '..tostring(N.extraWowheadHerbSpots))
 local function count(id,map) local l=N.spawns[id] and N.spawns[id][map]; return l and #l/2 or 0 end
 assert(count(566788,2482)>=30,'Marefoil, Mount Hyjal')
 assert(count(566786,2482)>=5,'Demonsage, Mount Hyjal')
 assert(count(654624,2482)>=10,'Hyjal Silphium, Mount Hyjal')
 assert(count(2046,2548)>=60,'Goldthorn, Riverglades')
 assert(count(2041,2548)>=40,'Liferoot, Riverglades')
 eq(N.nodeTypes[566788].kind,'herb');eq(N.nodeTypes[566788].skill,300)
 eq(N.nodeTypes[618987].name,'Stranglekelp')
 eq(N.nodeItemIDs['Marefoil'],248823);eq(N.nodeItemIDs['Demonsage'],248821);eq(N.nodeItemIDs['Heavy Thorium Vein'],10620)
 for id,zones in pairs(N.spawns) do for map,l in pairs(zones) do
  assert(#l%2==0,'odd coord list '..id..'/'..map)
  for i=1,#l do assert(l[i]>=0 and l[i]<=1,'coord out of range '..id..'/'..map) end
 end end
end)
