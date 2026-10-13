-- Camera positions are relative to a real club counter, not a miniature viewport.
local Timeline={Duration=13}
local kinds={cassette='recorder',envelope='envelope',call='telephone'}
local function ease(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
function Timeline.sample(id,t,variant)
 if not kinds[id]then return nil end
 t=math.max(0,t);local shot= t<3 and 1 or t<6 and 2 or t<10 and 3 or 4
 local starts={0,3,6,10};local lengths={3,3,4,3};local progress=ease((t-starts[shot])/lengths[shot])
 local eyes={{5.2,2.4,-9},{1.6,1.35,-2.6},{-2.2,1.1,-2.5},{4.1,2,-6.4}}
 local targets={{0,.2,-.8},{0,.2,0},{0,.4,-.25},{0,.5,-.5}}
 local actionAt,walkTime=6,3
 if id=='envelope'then eyes={{-4.6,2.8,-7.2},{-.9,2.1,-2.1},{2.8,1.7,-3.4},{-3.2,2.2,-5.6}};targets={{0,.35,-.4},{0,.12,0},{0,.5,-.2},{0,.7,-.6}};actionAt=2.8;walkTime=2.2
 elseif id=='call'then eyes={{-5.4,1.6,-8.4},{2.5,1.1,-3.2},{1.8,2.2,-3.8},{-4.3,1.8,-5.7}};targets={{0,.7,-.8},{0,.38,-.33},{0,1.4,-.7},{0,1.25,-.9}};actionAt=4.2;walkTime=1.8 end
 local eye=table.clone(eyes[shot]);eye[1]-=progress*(shot==1 and .6 or .16);eye[3]+=progress*.25
 eye[1]+=((variant or 2)-2)*.35
 return{shot=shot,progress=progress,eye=eye,target=targets[shot],prop=kinds[id],walk=ease(t/walkTime),action=ease((t-actionAt)/2),settle=ease((t-9)/2),reel=t*2.4,done=t>=Timeline.Duration}
end
return Timeline
