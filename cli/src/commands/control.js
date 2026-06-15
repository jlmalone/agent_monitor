import chalk from 'chalk';
import { loadRegistry } from '../lib/config.js';

export async function startAgent(alias, options) {
  if (options.all) {
    console.log(chalk.yellow('Starting all agents...'));
    // TODO: Implement via clawdbot sessions_spawn
    console.log(chalk.gray('Use: clawdbot agent start --all'));
    return;
  }
  
  const registry = await loadRegistry();
  const agent = registry.agents?.find(a => a.alias === alias);
  
  if (!agent) {
    console.log(chalk.red(`Agent "${alias}" not found.`));
    return;
  }
  
  console.log(chalk.green(`Starting ${alias}...`));
  // TODO: Integrate with clawdbot sessions_spawn
  console.log(chalk.gray(`Use: clawdbot sessions spawn --label ${alias} --task "..."`));
}

export async function stopAgent(alias, options) {
  if (options.all) {
    console.log(chalk.yellow('Stopping all agents...'));
    // TODO: Implement
    return;
  }
  
  const registry = await loadRegistry();
  const agent = registry.agents?.find(a => a.alias === alias);
  
  if (!agent) {
    console.log(chalk.red(`Agent "${alias}" not found.`));
    return;
  }
  
  console.log(chalk.yellow(`Stopping ${alias}...`));
  // TODO: Integrate with session management
  console.log(chalk.gray('Manual stop not yet implemented'));
}
