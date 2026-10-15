// Browser illustration of the UI response, not Roblox audio or input emulation.
let feedbackNode = null, feedbackScale = 1, feedbackAim = 1, feedbackFrame = 0;
let feedbackDown = false, feedbackPointer = 'mouse', demoPressSound = false;
let demoAudio = null, demoAudioEnabled = false, lastDemoHover = -1000;
const reduceDemoMotion = matchMedia('(prefers-reduced-motion: reduce)');
const soundToggle = document.querySelector('#demo-sound');
function resetFeedback() {
  feedbackNode = null; feedbackDown = false; demoPressSound = false; feedbackScale = feedbackAim = 1;
  canvas.style.cursor = 'default'; canvas.dataset.feedback = 'idle';
  if (feedbackFrame) cancelAnimationFrame(feedbackFrame);
  feedbackFrame = 0;
}
function demoHit(e) {
  const l = layouts[device + ':' + screen], r = canvas.getBoundingClientRect();
  const px = (e.clientX - r.left) * l.w / r.width, py = (e.clientY - r.top) * l.h / r.height;
  return l.nodes.filter(n => n.class === 'TextButton' && n.active !== false && n.interactable !== false &&
    !/Dismiss|Backdrop/.test(n.name) && !(n.w > l.w * .8 && n.h > l.h * .7) &&
    px >= Math.max(n.x, n.clip.x) && px < Math.min(n.x + n.w, n.clip.right) &&
    py >= Math.max(n.y, n.clip.y) && py < Math.min(n.y + n.h, n.clip.bottom))
    .sort((a,b) => a.z-b.z).at(-1) || null;
}
function demoSound(kind) {
  if (!demoAudioEnabled || !demoAudio || demoAudio.state !== 'running') return;
  const now = performance.now();
  if (kind === 'hover' && now-lastDemoHover < 90) return;
  if (kind === 'hover') lastDemoHover = now;
  const osc = demoAudio.createOscillator(), gain = demoAudio.createGain();
  const t = demoAudio.currentTime;
  osc.type = 'triangle'; osc.frequency.setValueAtTime(kind === 'hover' ? 1400 : 760,t);
  osc.frequency.exponentialRampToValueAtTime(kind === 'hover' ? 800 : 260,t+.025);
  gain.gain.setValueAtTime(.0001,t);
  gain.gain.exponentialRampToValueAtTime(kind === 'hover' ? .012 : .028,t+.003);
  gain.gain.exponentialRampToValueAtTime(.0001,t+.032);
  osc.connect(gain); gain.connect(demoAudio.destination);
  osc.onended = () => {osc.disconnect();gain.disconnect()};
  osc.start(t); osc.stop(t+.036);
  canvas.dataset.audioCount = String(Number(canvas.dataset.audioCount || 0)+1);
}
soundToggle.onclick = async () => {
  if (demoAudioEnabled) {
    demoAudioEnabled = false; soundToggle.textContent = 'Звук макета: выкл.';
    soundToggle.setAttribute('aria-pressed','false'); return;
  }
  try {
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) throw new Error('No Web Audio');
    demoAudio = demoAudio || new Audio(); await demoAudio.resume();
    demoAudioEnabled = demoAudio.state === 'running';
    soundToggle.textContent = demoAudioEnabled ? 'Звук макета: вкл.' : 'Звук макета: выкл.';
    soundToggle.setAttribute('aria-pressed',String(demoAudioEnabled));
    demoSound('click');
  } catch (_) {soundToggle.textContent = 'Звук недоступен';}
};
function animateDemoFeedback() {
  feedbackFrame = 0;
  feedbackScale += (feedbackAim-feedbackScale)*.35;
  if (Math.abs(feedbackScale-feedbackAim) < .0003) feedbackScale = feedbackAim;
  canvas.dataset.feedbackScale = feedbackScale.toFixed(4);
  draw(canvas,device+':'+screen);
  if (feedbackScale !== feedbackAim) feedbackFrame = requestAnimationFrame(animateDemoFeedback);
}
function aimFeedback(node, down) {
  if (feedbackNode !== node) feedbackScale = 1;
  feedbackNode = node;
  // Ballot and theme cards keep their own selection animation in the game.
  const ownsMotion = node && (/^Suspect_|AnotherClueRound/.test(node.name) || screen === 'match-topic');
  feedbackAim = !node || ownsMotion || reduceDemoMotion.matches ? 1 : down ? .985 : 1.01;
  canvas.dataset.feedback = !node ? 'idle' : down ? 'press' : 'hover';
  if (reduceDemoMotion.matches) feedbackScale = 1;
  if (!feedbackFrame) feedbackFrame = requestAnimationFrame(animateDemoFeedback);
}
canvas.addEventListener('pointermove', e => {
  if (feedbackDown) return;
  const n = demoHit(e), changed = n !== feedbackNode;
  feedbackPointer = e.pointerType;
  canvas.style.cursor = n ? 'pointer' : 'default';
  if (e.pointerType === 'touch') return;
  if (n && changed) demoSound('hover');
  aimFeedback(n,false);
});
canvas.addEventListener('pointerdown', e => {
  const n = demoHit(e); if (!n) return;
  feedbackDown = true; feedbackPointer = e.pointerType;
  demoSound('click'); demoPressSound = true;
  canvas.setPointerCapture(e.pointerId); aimFeedback(n,true);
});
canvas.addEventListener('pointerup', e => {
  feedbackDown = false;
  aimFeedback(feedbackPointer === 'touch' ? null : demoHit(e),false);
});
canvas.addEventListener('pointercancel', () => {resetFeedback();draw(canvas,device+':'+screen)});
canvas.addEventListener('pointerleave', () => {
  if (!feedbackDown) {resetFeedback();draw(canvas,device+':'+screen)}
});
canvas.addEventListener('click', e => {if (demoHit(e) && !demoPressSound) demoSound('click');demoPressSound=false},true);
function releaseDemoFeedback() {resetFeedback();draw(canvas,device+':'+screen)}
window.addEventListener('blur',releaseDemoFeedback);
reduceDemoMotion.addEventListener('change',releaseDemoFeedback);
document.addEventListener('visibilitychange',() => {if(document.hidden)releaseDemoFeedback()});
window.addEventListener('pagehide',() => {resetFeedback();if(demoAudio)demoAudio.close().catch(()=>{})});
