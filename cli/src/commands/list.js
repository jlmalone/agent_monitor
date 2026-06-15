import chalk from 'chalk';
import Table from 'cli-table3';
import { loadRegistry, loadAgentState } from '../lib/config.js';
import { computeStatus, formatStatusSymbol, timeAgo } from '../lib/status.js';

export async function listAgents() {
  const registry = await loadRegistry();
  
  if (!registry.agents?.length) {
    console.log(chalk.yellow('No agents registered.'));
    return;
  }
  
  const table = new Table({
    head: [
      chalk.white('Agent'),
      chalk.white('Assignment'),
      chalk.white('Status'),
      chalk.white('Last Activity')
    ],
    colWidths: [14, 30, 12, 18],
    style: { head: [], border: [] }
  });
  
  let activeCount = 0;
  let blockedCount = 0;
  let completedCount = 0;
  let errorCount = 0;
  
  for (const agent of registry.agents) {
    const state = await loadAgentState(agent.alias);
    const status = computeStatus(state, true); // TODO: check actual session
    
    if (status === 'active') activeCount++;
    if (status === 'blocked') blockedCount++;
    if (status === 'completed') completedCount++;
    if (status === 'error') errorCount++;
    
    const assignment = state?.currentAssignment || '-';
    const truncatedAssignment = assignment.length > 27 
      ? assignment.substring(0, 24) + '...' 
      : assignment;
    
    table.push([
      chalk.bold(agent.alias),
      truncatedAssignment,
      formatStatusSymbol(status) + ' ' + status.charAt(0).toUpperCase() + status.slice(1),
      timeAgo(state?.lastActivity)
    ]);
  }
  
  console.log(table.toString());
  console.log();
  
  // Summary line
  const total = registry.agents.length;
  let summary = chalk.green(`✓ ${activeCount}/${total} active`);
  if (completedCount > 0) summary += chalk.blue(` | ${completedCount} completed`);
  if (blockedCount > 0) summary += chalk.hex('#FFA500')(` | ${blockedCount} blocked`);
  if (errorCount > 0) summary += chalk.red(` | ${errorCount} error`);
  
  console.log(summary);
}
