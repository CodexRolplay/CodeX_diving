const hud = document.getElementById('hud');
const oxygenText = document.getElementById('oxygenText');
const oxygenBar = document.getElementById('oxygenBar');
const tankText = document.getElementById('tankText');
const tankBar = document.getElementById('tankBar');
const statusEl = document.getElementById('status');

function setVisible(visible) {
  hud.classList.toggle('hidden', !visible);
}

function setStatus(status) {
  statusEl.textContent = status;
  statusEl.classList.remove('stable', 'low', 'critical');
  const klass = status === 'CRITICAL' ? 'critical' : status === 'LOW' ? 'low' : 'stable';
  statusEl.classList.add(klass);
}

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action === 'visible') {
    setVisible(!!data.visible);
    return;
  }
  if (data.action === 'update') {
    setVisible(data.visible !== false);
    oxygenText.textContent = `${Math.max(0, data.oxygen || 0)}s`;
    oxygenBar.style.width = `${Math.max(0, Math.min(100, data.oxygenPct || 0))}%`;
    tankText.textContent = `${Math.max(0, data.tank || 0)}%`;
    tankBar.style.width = `${Math.max(0, Math.min(100, data.tank || 0))}%`;
    setStatus(data.status || 'STABLE');
  }
});
