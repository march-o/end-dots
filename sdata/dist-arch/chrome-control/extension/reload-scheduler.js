let reloadScheduled = false;

export function scheduleRuntimeReload({ id, send, reload, setTimer = setTimeout }) {
  if (reloadScheduled) throw new Error('Extension reload is already scheduled');
  reloadScheduled = true;
  send({ id, ok: true, result: { reloading: true } });
  setTimer(() => reload(), 500);
}
