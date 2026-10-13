-- Assertions run against helpers extracted from the current Match sources.
local checks = 0
local function player(userId)
 return {UserId=userId,Parent=Players,attributes={},GetAttribute=function(self,key) return self.attributes[key] end}
end
local p = player(101)
local function reset()
 p.Parent=Players;p.attributes={}
 round={started=true,rolesAssigned=true,resultStarted=true,aborting=false,terminal=true,
  playerIndex={[101]=1},players={p},disconnected={},participation=Reconnect.newParticipation({101,102,103})}
end
local function check(label,expected)
 local actual=eligibleForCompletedMatch(p)
 assert(actual==expected,label..': expected '..tostring(expected)..', got '..tostring(actual))
 checks+=1
end
reset();check('completed full match with terminal reconnect ledger',true)
reset();round.started=false;check('round never started',false)
reset();round.rolesAssigned=false;check('partial round before roles',false)
reset();round.resultStarted=false;check('incomplete match',false)
reset();round.aborting=true;check('cancelled match',false)
reset();p.Parent={};check('departed player',false)
reset();p.attributes.SpyExplicitLeave=true;check('explicit abandonment',false)
reset();round.disconnected[101]=os.time()+90;check('temporary disconnected player at result',false)
reset();round.playerIndex[101]=nil;check('removed roster entry',false)
reset();round.players[1]=player(101);check('stale Player before authenticated replacement',false)
reset();round.participation=nil;check('no participation ledger',false)
reset();round.participation:forfeit(101);check('forfeit in original ledger',false)
reset();round.participation:miss(101);round.participation:miss(101);check('two missed turns',false)
reset();round.participation=Reconnect.newParticipation({102,103,104});check('late join outside starting roster',false)
reset();round.participation=Reconnect.newParticipation({101,102});check('short two-player match',false)
reset();round.participation:miss(101);round.participation:respond(101,'hint');check('active member recovers one missed turn',true)
reset();round.participation:forfeit(101);round.participation:respond(101,'vote');check('responses cannot clear forfeit',false)
print('Match reward eligibility: '..checks..' assertions passed')
