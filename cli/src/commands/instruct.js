import chalk from 'chalk';
import { writeFile, mkdir } from 'fs/promises';
import { join } from 'path';
import { loadRegistry, getAgentsDir } from '../lib/config.js';

export async function instructAgent(alias, message) {
  const registry = await loadRegistry();
  const agent = registry.agents?.find(a => a.alias === alias);
  
  if (!agent) {
    console.log(chalk.red(`Agent "${alias}" not found.`));
    return;
  }
  
  // Write to instructions file
  const instructionsPath = join(getAgentsDir(), alias, 'instructions.md');
  const timestamp = new Date().toISOString();
  const content = `## Instruction [${timestamp}]\n\n${message}\n\n---\n\n`;
  
  try {
    await mkdir(join(getAgentsDir(), alias), { recursive: true });
    await writeFile(instructionsPath, content, { flag: 'a' });
    console.log(chalk.green(`✓ Instruction sent to ${alias}`));
    console.log(chalk.gray(`  Written to: ${instructionsPath}`));
    
    // TODO: Also send via sessions_send for immediate delivery
    console.log(chalk.gray('  Note: Use sessions_send for immediate delivery'));
  } catch (err) {
    console.log(chalk.red(`Failed to write instruction: ${err.message}`));
  }
}
