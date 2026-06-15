import chalk from 'chalk';
import { loadRegistry, loadAgentState } from '../lib/config.js';
import { computeStatus, formatStatus, timeAgo } from '../lib/status.js';

export async function statusAgent(alias) {
  const registry = await loadRegistry();
  const agentConfig = registry.agents?.find(a => a.alias === alias);
  
  if (!agentConfig) {
    console.log(chalk.red(`Agent "${alias}" not found in registry.`));
    return;
  }
  
  const state = await loadAgentState(alias);
  const status = computeStatus(state, true);
  
  console.log();
  console.log(chalk.bold.white(`━━━ ${alias.toUpperCase()} ━━━`));
  console.log();
  
  // Status
  console.log(chalk.gray('STATUS:'), formatStatus(status));
  console.log(chalk.gray('LAST ACTIVITY:'), timeAgo(state?.lastActivity));
  console.log();
  
  // Persona
  console.log(chalk.bold.cyan('PERSONA'));
  console.log(chalk.white(agentConfig.persona || state?.persona || 'Not defined'));
  console.log();
  
  // Mandate
  console.log(chalk.bold.cyan('MANDATE'));
  console.log(chalk.white(agentConfig.mandate || state?.mandate || 'Not defined'));
  console.log();
  
  // Work Directory
  console.log(chalk.bold.cyan('WORKSPACE'));
  console.log(chalk.white(agentConfig.workDir));
  if (agentConfig.port) {
    console.log(chalk.gray(`Port: ${agentConfig.port}`));
  }
  console.log();
  
  // Current Assignment
  console.log(chalk.bold.cyan('CURRENT ASSIGNMENT'));
  console.log(chalk.white(state?.currentAssignment || 'None'));
  console.log();
  
  // Questions
  const questions = state?.questions?.filter(q => !q.answeredAt) || [];
  console.log(chalk.bold.cyan(`QUESTIONS (${questions.length} pending)`));
  if (questions.length === 0) {
    console.log(chalk.gray('No pending questions'));
  } else {
    questions.forEach((q, i) => {
      console.log(chalk.yellow(`  [${q.id}] ${q.text}`));
      console.log(chalk.gray(`       Asked: ${timeAgo(q.askedAt)}`));
    });
  }
  console.log();
  
  // Progress
  const progress = state?.progress?.slice(-10) || [];
  console.log(chalk.bold.cyan(`PROGRESS (last ${progress.length})`));
  if (progress.length === 0) {
    console.log(chalk.gray('No progress entries'));
  } else {
    progress.forEach(entry => {
      console.log(chalk.gray(`  • ${entry}`));
    });
  }
  console.log();
}
