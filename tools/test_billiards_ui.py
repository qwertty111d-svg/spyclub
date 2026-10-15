#!/usr/bin/env python3
"""Exercise real billiards GUI construction, responsive layout and public state."""
from pathlib import Path
import subprocess
import tempfile
import unittest

from render_billiards_layout_preview import CLIENT, ROOT, VARIANTS, assemble_harness


VIEWPORTS = ((1440, 900), (1920, 1080), (360, 640), (280, 640), (360, 540), (844, 360))
GEOMETRY = r'''
local checks=0
local function check(value,message)checks+=1;assert(value,message)end
local function visible(node)
 while node and node~=playerGui do if node.Visible==false then return false end;node=node.Parent end
 return true
end
local function rect(node)
 local p,s=node.AbsolutePosition,node.AbsoluteSize
 local r={x=p.X,y=p.Y,right=p.X+s.X,bottom=p.Y+s.Y}
 local parent=node.Parent
 while parent and parent~=playerGui do
  if parent.ClipsDescendants or parent.ClassName=='ScrollingFrame'then
   local q,z=parent.AbsolutePosition,parent.AbsoluteSize
   r.x=math.max(r.x,q.X);r.y=math.max(r.y,q.Y);r.right=math.min(r.right,q.X+z.X);r.bottom=math.min(r.bottom,q.Y+z.Y)
  end
  parent=parent.Parent
 end
 return r
end
local function overlaps(a,b)
 return a.x<b.right-.1 and b.x<a.right-.1 and a.y<b.bottom-.1 and b.y<a.bottom-.1
end
local function audit()
 local buttons={}
 for _,node in ipairs(gui:GetDescendants())do
  if visible(node)and(node.ClassName=='TextButton'or node.ClassName=='TextBox')and node.Active~=false then
   local r=rect(node)
   if r.right>r.x and r.bottom>r.y then
    check(r.x>=-.1 and r.y>=-.1 and r.right<=WIDTH+.1 and r.bottom<=HEIGHT+.1,'offscreen hitbox '..node.Name)
    for _,other in ipairs(buttons)do
     if not node:IsDescendantOf(other.node)and not other.node:IsDescendantOf(node)then
      check(not overlaps(r,other.rect),'hitbox overlap '..node.Name..' / '..other.node.Name)
     end
    end
    table.insert(buttons,{node=node,rect=r})
   end
  end
 end
end
audit()
check(panel.Size.X.Offset<=WIDTH-24,'dock fits viewport')
check(shotButton.Size.Y.Offset>=44 and panel.Exit.Size.Y.Offset>=44,'main controls retain touch height')
check(shotButton:FindFirstChild('BilliardsInputScale').Scale==1,'hold control geometry is owned')
check(spinHit:FindFirstChild('BilliardsInputScale').Scale==1,'spin hit geometry is owned')
if VARIANT=='mode'then
 check(startButton.Parent==modeFrame,'primary start action is outside scrolling list')
 check(startButton.AbsolutePosition.Y>=modeFrame.Content.AbsolutePosition.Y+modeFrame.Content.AbsoluteSize.Y,'primary action leaves a scroll gutter')
 local content=modeFrame.Content
 content.CanvasPosition=Vector2.new(0,content.CanvasSize.Y.Offset-content.AbsoluteSize.Y)
 audit()
 for _,node in ipairs({timeButton,modeDescription,content.ClubLeaderboard})do
  check(node.AbsoluteSize.X>0,'selected game details remain present')
 end
elseif VARIANT=='rules'then
 local bottom=math.max(0,instructions.CanvasSize.Y.Offset-instructions.AbsoluteSize.Y)
 instructions.CanvasPosition=Vector2.new(0,bottom);audit()
 local r=rect(instructions.Configure)
 check(r.bottom>r.y,'game chooser is reachable through rules scroll')
elseif VARIANT=='hud'then
 check(canAim(),'baseline member may aim')
 fineAimToggle.Activated:Fire();updateHud();layoutUI();audit()
 check(fineAimExpanded and angleBox.Visible,'fine aim opens without losing its input')
 check(not spinExpanded,'fine aim closes compact spin')
 fineAimToggle.Activated:Fire();updateHud();layoutUI()
 if compactSpin then
  spinToggle.Activated:Fire();updateHud();layoutUI();audit()
  check(spinExpanded and spinFrame.Visible and not spinToggle.Visible,'spin popover owns its trigger area')
  fineAimToggle.Activated:Fire();updateHud();layoutUI();audit()
  check(not spinExpanded and fineAimExpanded,'secondary panels do not compete for short-screen space')
  fineAimToggle.Activated:Fire();spinExpanded=false;updateHud();layoutUI()
 end
 -- Nine-ball target icons, guidance and push-out keep their own geometry.
 snapshot.mode='pool9';visualMode=snapshot.mode;snapshot.pushOutAvailable=true;snapshot.lowest=2
 updateHud();layoutUI();audit()
 for _,card in ipairs(playerCards)do for _,icon in pairs(card.icons)do if icon.Visible then
  check(icon.Position.X.Offset+icon.Size.X.Offset<=card.balls.AbsoluteSize.X+.1,'all nine targets fit player strip')
 end end end
 snapshot.phase='decision';snapshot.decision={kind='pyramid_break'};snapshot.decisionOptions={'accept','pass','rerack_self','rerack_other'}
 updateHud();layoutUI();audit()
 check(decisionFrame.Visible and not canAim(),'decision does not allow aiming')
elseif VARIANT=='result'then
 check(roundResult.Visible and not topHud.Visible and not powerBar.Visible,'result owns its summary space')
end
print('Billiards geometry checks passed: '..checks)
'''

STATE = r'''
local function check(value,message)assert(value,message)end
local actions={};send=function(command,extra)table.insert(actions,{command=command,extra=extra})end
check(canAim(),'own aiming turn starts available')
instructions.Visible=true;check(not canAim(),'rules block aiming');instructions.Visible=false
modeSheet.Visible=true;check(not canAim(),'mode picker blocks aiming');modeSheet.Visible=false
snapshot.ballInHand='home';updateHud();check(not canAim(),'ball in hand blocks stroke aim')
check(shotButton.Text=='Поставь биток'and not shotButton.Active,'placement gets its real next action')
snapshot.ballInHand=nil;snapshot.turn=102;updateHud();check(not canAim()and not shotButton.Active,'opponent turn cannot shoot')
snapshot.turn=101;snapshot.phase='moving';updateHud();check(not canAim()and shotButton.Text=='Шары в игре','motion has authoritative busy status')
snapshot.phase='aiming';shotPending=true;updateHud();check(not shotButton.Active and shotButton.Text=='Удар…','pending stroke cannot duplicate')
shotPending=false;updateHud();check(shotButton.Active,'confirmed aim restores hold action')
snapshot.mode='pyramid';visualMode='pyramid';snapshot.shots=4;updateHud();aimButton.Activated:Fire()
check(selectingCue and instructions.Visible==false,'pyramid cue selection retains original callback')
selectingCue=false;snapshot.mode='pool9';visualMode='pool9';snapshot.pushOutAvailable=true;updateHud()
pushOutButton.Activated:Fire();check(pushOut,'push-out retains local preparation state')
check(#actions==0,'aim and push-out preparation do not send shots')
snapshot.phase='decision';snapshot.decision={kind='nine_pushout'};snapshot.decisionOptions={'accept','pass'};updateHud()
decisionFrame.accept.Activated:Fire();check(actions[1].command=='decision'and actions[1].extra.choice=='accept','decision sends original explicit choice')
local observed={id=102,name='Spectator',score=0};snapshot.players={observed};snapshot.turn=102;snapshot.phase='aiming';updateHud()
check(not member()and not canAim(),'spectator never gains aiming')
check(joinButton.Visible and not panel.Controls.Visible,'spectator sees join instead of shot controls')
check(#actions==1,'public presentation never sends unsolicited gameplay')
print('Billiards public state checks passed')
'''


CAMERA_BOUNDARIES = r'''
-- Native Vector3/CFrame are unavailable in Luau CLI. These arithmetic-only
-- boundaries execute the exact live camera function and capture its outputs.
local VectorMeta={}
function VectorMeta.__add(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
function VectorMeta.__sub(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
function VectorMeta.__mul(a,b)
 if type(a)=='number'then a,b=b,a end
 return Vector3.new(a.X*b,a.Y*b,a.Z*b)
end
Vector3.new=function(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},VectorMeta)end
CFrame.lookAt=function(from,target,up)return{from=from,target=target,up=up}end
local cameraFitBounds
snapshot.center=Vector3.new(0,0,0);snapshot.height=0;snapshot.scale=1
cameraRestore={}
'''

CAMERA_ASSERTIONS = r'''
local function cameraAboveDock()
 cameraLayoutKey=nil;fitCamera()
 assert(cameraFitBounds,'actual camera function executed')
 assert(camera.CFrame and camera.CFrame.target,'actual camera emitted its native-boundary pose')
 local dockTop=panel.AbsolutePosition.Y
 assert(cameraFitBounds.bottom<=dockTop+.1,'actual camera bounds overlap dock: '..cameraFitBounds.bottom..' > '..dockTop)
end
cameraAboveDock()
fineAimToggle.Activated:Fire();updateHud();layoutUI();cameraAboveDock()
assert(fineAimExpanded and angleBox.Visible,'actual expanded fine aim was checked')
print('Billiards camera stays above dock')
'''


def camera_probe_source():
    source=CLIENT.read_text()
    first=source.index('local function fitCamera()')
    camera=source[first:source.index('RunService.RenderStepped:Connect',first)]
    capture='        local bottom=math.max(top+100,height-panel.Size.Y.Offset-24-bottomInset.Y)'
    if camera.count(capture)!=1:
        raise ValueError('live billiards camera bounds marker changed')
    # The sole inserted observation exposes actual local camera limits; no
    # camera formula is replaced or repeated in the test.
    return CAMERA_BOUNDARIES+camera.replace(capture,capture+'\n        cameraFitBounds={top=top,bottom=bottom}',1)+CAMERA_ASSERTIONS


class BilliardsUITests(unittest.TestCase):
    def run_luau(self, source):
        with tempfile.TemporaryDirectory(prefix='spy-billiards-ui-test-') as directory:
            path=Path(directory)/'test.luau'
            path.write_text(source)
            result=subprocess.run(['/workspace/.spy-tools/bin/luau',str(path)],cwd=ROOT,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr+result.stdout)
            return result.stdout

    def test_actual_gui_geometry_across_viewports_and_states(self):
        for variant in VARIANTS:
            for width,height in VIEWPORTS:
                with self.subTest(variant=variant,viewport=(width,height)):
                    self.assertIn('Billiards geometry checks passed',self.run_luau(assemble_harness(variant,width,height,GEOMETRY)))

    def test_actual_camera_keeps_expanded_fine_aim_above_dock(self):
        probe=camera_probe_source()
        for width,height in VIEWPORTS:
            with self.subTest(viewport=(width,height)):
                self.assertIn('Billiards camera stays above dock',self.run_luau(assemble_harness('hud',width,height,probe)))

    def test_public_state_and_callbacks_preserve_input_authority(self):
        self.assertIn('Billiards public state checks passed',self.run_luau(assemble_harness('hud',360,640,STATE)))



if __name__=='__main__':unittest.main()
