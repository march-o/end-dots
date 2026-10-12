// Accept success only for a confirmed outcome in the requested frame.
export function normalizePageResponse(command, response, profile) {
  if (response.ok !== true) return { ...response, ok: false, profile, code: response.code || 'PAGE_EXCEPTION', error: String(response.error || 'Page action failed').slice(0, 1000) };
  if (!Array.isArray(response.result) || response.result.length === 0 || response.result.some(frame => !frame || frame.result == null || frame.error)) return { ok: false, profile, code: 'INVALID_PAGE_RESULT', uncertain: command.action !== 'snapshot', error: 'Invalid page execution result' };
  if (command.action === 'snapshot') {
    if (command.allFrames !== true && (response.result.length !== 1 || response.result[0].frameId !== (command.frameId ?? 0)))
      return { ok: false, profile, code: 'WRONG_FRAME', uncertain: false, error: 'Snapshot did not return the requested frame' };
    return { ...response, profile };
  }
  if (response.result.length !== 1 || response.result[0].frameId !== (command.frameId ?? 0)) return { ok: false, profile, code: 'WRONG_FRAME', uncertain: true, error: 'Action did not confirm the requested frame' };
  const result = response.result[0].result;
  const postcondition = result.postcondition;
  if (!command.expect || result.action !== command.action || result.selector !== command.selector
    || result.verified !== true || result.outcome !== 'verified'
    || postcondition?.selector !== command.expect.selector || postcondition?.state !== command.expect.state
    || postcondition.before !== false || postcondition.after !== true) return {
    ...response, ok: false, profile, code: result.code || 'UNVERIFIED_ACTION', uncertain: true,
    error: 'Input may have been applied, but the requested outcome was not verified. Inspect a fresh snapshot; do not automatically replay.',
  };
  return { ...response, profile };
}
