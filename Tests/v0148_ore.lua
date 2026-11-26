local N,test,eq=...
test('0.14.8 Ore: Wowhead Forever mining spots are loaded',function()
 assert((N.extraOreSpots or 0)>=900,'expected ~960 added ore spots, got '..tostring(N.extraOreSpots))
 local function count(id,map) local l=N.spawns[id] and N.spawns[id][map]; return l and #l/2 or 0 end
 assert(count(566779,2482)>=110,'Heavy Thorium, Mount Hyjal') -- 128 on Wowhead, near-duplicates merged
 assert(count(656333,1438)>=50,'Large Amber, Teldrassil')
 assert(count(656332,1438)>=15,'Amber, Teldrassil')
 assert(count(1735,2548)>=120,'Iron in Riverglades')
 eq(N.nodeTypes[566779].kind,'ore');eq(N.nodeTypes[566779].skill,300)
 eq(N.nodeTypes[656333].name,'Large Chunk of Amber');eq(N.nodeItemIDs['Chunk of Amber'],2770)
 for id,zones in pairs(N.spawns) do for map,l in pairs(zones) do
  assert(#l%2==0,'odd coord list '..id..'/'..map)
  for i=1,#l do assert(l[i]>=0 and l[i]<=1,'coord out of range '..id..'/'..map) end
 end end
end)
