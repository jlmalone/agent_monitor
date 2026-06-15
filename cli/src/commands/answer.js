import chalk from 'chalk';
import { readFile, writeFile } from 'fs/promises';
import { loadRegistry, getStatePath } from '../lib/config.js';

export async function answerQuestion(alias, questionId, response) {
  const registry = await loadRegistry();
  const agent = registry.agents?.find(a => a.alias === alias);
  
  if (!agent) {
    console.log(chalk.red(`Agent "${alias}" not found.`));
    return;
  }
  
  const statePath = getStatePath(alias);
  
  try {
    const data = await readFile(statePath, 'utf-8');
    const state = JSON.parse(data);
    
    const question = state.questions?.find(q => q.id === questionId);
    if (!question) {
      console.log(chalk.red(`Question "${questionId}" not found.`));
      return;
    }
    
    question.answeredAt = Date.now();
    question.answer = response;
    
    await writeFile(statePath, JSON.stringify(state, null, 2));
    
    console.log(chalk.green(`✓ Answered question ${questionId}`));
    console.log(chalk.gray(`  Q: ${question.text}`));
    console.log(chalk.gray(`  A: ${response}`));
  } catch (err) {
    console.log(chalk.red(`Failed to answer question: ${err.message}`));
  }
}
