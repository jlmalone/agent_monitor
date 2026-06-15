import chalk from 'chalk';

// Status colors and symbols
export const STATUS = {
  active: { symbol: '●', color: chalk.green, label: 'Active' },
  idle: { symbol: '○', color: chalk.yellow, label: 'Idle' },
  blocked: { symbol: '◐', color: chalk.hex('#FFA500'), label: 'Blocked' },
  completed: { symbol: '✓', color: chalk.blue, label: 'Completed' },
  error: { symbol: '✖', color: chalk.red, label: 'Error' },
  offline: { symbol: '◌', color: chalk.gray, label: 'Offline' }
};

export function computeStatus(state, sessionActive = false) {
  if (!state) return 'offline';
  
  const now = Date.now();
  const lastActivity = state.lastActivity || 0;
  const minutesSinceActivity = (now - lastActivity) / 1000 / 60;
  
  // Check for unanswered questions
  const hasQuestions = state.questions?.some(q => !q.answeredAt);
  
  // Priority: error > blocked > completed > active > idle > offline
  if (state.status === 'error') return 'error';
  if (state.status === 'blocked') return 'blocked';
  if (state.status === 'completed') return 'completed';
  if (hasQuestions) return 'blocked';
  if (!sessionActive) return 'offline';
  if (minutesSinceActivity > 10) return 'idle';
  return 'active';
}

export function formatStatus(status) {
  const s = STATUS[status] || STATUS.offline;
  return s.color(`${s.symbol} ${s.label}`);
}

export function formatStatusSymbol(status) {
  const s = STATUS[status] || STATUS.offline;
  return s.color(s.symbol);
}

export function timeAgo(timestamp) {
  if (!timestamp) return 'never';
  
  const seconds = Math.floor((Date.now() - timestamp) / 1000);
  
  if (seconds < 60) return `${seconds}s ago`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
}
