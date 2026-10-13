-- Finite, lazy owner-only loading; late reads cannot overwrite typed notes.
local Client={};Client.__index=Client
function Client.new(ui)
 return setmetatable({ui=ui,serial=0,destroyed=false,loaded=false,pending=false,revision=0},Client)
end
function Client:emit(key)
 self.ui.noteStatus=key
 if self.ui.updateNoteStatus then self.ui:updateNoteStatus()end
end
function Client:request(payload,callback)
 if self.destroyed or self.pending then return false end
 local folder=game:GetService('ReplicatedStorage'):FindFirstChild('SpyPhonePersonalRemotes');local r=folder and folder:FindFirstChild('Request')
 if not r or not r:IsA('RemoteFunction')then self:emit('note_loading');return false end
 self.serial+=1;local serial=self.serial;self.pending=true
 self:emit(payload.action=='read'and'note_loading'or'note_saving')
 task.delay(8,function()
  if not self.destroyed and self.pending and self.serial==serial then
   self.pending=false;self:emit(payload.action=='read'and'note_load_failed'or'note_failed')
  end
 end)
 task.spawn(function()
  local ok,result=pcall(function()return r:InvokeServer(payload)end)
  if self.destroyed or serial~=self.serial then return end
  self.pending=false
  if ok and type(result)=='table'and result.ok then callback(result)
  else self:emit(type(result)=='table'and result.code or'note_failed')end
 end)
 return true
end
function Client:load()
 if self.loaded then return end
 local ui=self.ui;local before=ui.note
 self:request({action='read'},function(d)
  if type(d.note)~='string'or not utf8.len(d.note)or #d.note>16384 or type(d.noteRevision)~='number'then self:emit('note_load_failed');return end
  self.loaded=true;self.revision=d.noteRevision;self.saved=d.note;self.savedAt=d.noteSavedAt;self.studio=d.studio
  if ui.note==before and not ui.noteDirty then
   ui.note=d.note
   if ui.noteEditor and ui.noteEditor.Parent then ui.noteEditor.Text=d.note end
  end
  ui.noteDirty=ui.note~=self.saved
  self:emit(ui.noteDirty and'note_unsaved'or(self.studio and'note_studio'or'note_saved'))
 end)
end
function Client:save()
 if self.pending then return end
 local ui=self.ui
 if not self.loaded then self:load();return end
 local text=ui.note
 local length=type(text)=='string'and utf8.len(text)
 if not length or length>4096 or #text>16384 then self:emit('note_invalid');return end
 if text==self.saved then self:emit(self.studio and'note_studio'or'note_saved');return end
 -- An uncertain retry uses the same receipt ID and expected revision, not a second mutation.
 if not self.attempt or self.attempt.text~=text or self.attempt.revision~=self.revision then
  local nonce=game:GetService('HttpService'):GenerateGUID(false)
  self.attempt={text=text,revision=self.revision,nonce=nonce}
 end
 local attempt=self.attempt
 self:request({action='save',text=attempt.text,revision=attempt.revision,nonce=attempt.nonce},function(d)
  if type(d.noteRevision)~='number'then self:emit('note_failed');return end
  self.revision=d.noteRevision;self.saved=attempt.text;self.savedAt=d.noteSavedAt;self.studio=d.studio;self.attempt=nil
  ui.noteDirty=ui.note~=self.saved
  self:emit(ui.noteDirty and'note_unsaved'or(self.studio and'note_studio'or'note_saved'))
 end)
end
function Client:changed()
 self.ui.noteDirty=self.ui.note~=self.saved
 if not self.pending then self:emit(self.loaded and(self.ui.noteDirty and'note_unsaved'or(self.studio and'note_studio'or'note_saved'))or'note_loading')end
end
function Client:reload()
 -- Explicit conflict recovery: load the current revision while preserving the local draft.
 if self.pending then return end
 self.loaded=false;self:load()
end
function Client:destroy()self.destroyed=true;self.serial+=1;self.pending=false end
return Client
