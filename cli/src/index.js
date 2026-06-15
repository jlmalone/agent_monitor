#!/usr/bin/env node

const args = process.argv.slice(2);

if (args[0] === 'quickreport') {
  const alias = args[1];
  const tokensIndex = args.findIndex((arg) => arg === '--tokens' || arg === '-t');
  let tokens;
  let messageArgs = args.slice(2);
  if (tokensIndex !== -1) {
    tokens = parseInt(args[tokensIndex + 1], 10);
    messageArgs = args.slice(2, tokensIndex).concat(args.slice(tokensIndex + 2));
  }
  const message = messageArgs.join(' ');

  if (!alias || !message) {
    console.error('Usage: am quickreport <alias> <message> [--tokens <number>]');
    process.exit(1);
  }

  const { quickReport } = await import('./commands/quickreport.js');
  await quickReport(alias, message, { tokens });
  process.exit(0);
}

const { Command } = await import('commander');

const program = new Command();

program
  .name('am')
  .description('Agent Monitor - CLI for managing AI subagents')
  .version('1.0.0');

program
  .command('list')
  .alias('ls')
  .description('List all agents with status')
  .action(async (...args) => {
    const { listAgents } = await import('./commands/list.js');
    return listAgents(...args);
  });

program
  .command('status <alias>')
  .description('Show detailed status for an agent')
  .action(async (alias) => {
    const { statusAgent } = await import('./commands/status.js');
    return statusAgent(alias);
  });

program
  .command('start <alias>')
  .description('Start an agent')
  .option('--all', 'Start all agents')
  .action(async (...args) => {
    const { startAgent } = await import('./commands/control.js');
    return startAgent(...args);
  });

program
  .command('stop <alias>')
  .description('Stop an agent')
  .option('--all', 'Stop all agents')
  .action(async (...args) => {
    const { stopAgent } = await import('./commands/control.js');
    return stopAgent(...args);
  });

program
  .command('instruct <alias> <message>')
  .description('Send instruction to an agent')
  .action(async (alias, message) => {
    const { instructAgent } = await import('./commands/instruct.js');
    return instructAgent(alias, message);
  });

program
  .command('quickreport <alias> <message>')
  .description('Quick status/progress update (updates state.json)')
  .option('-t, --tokens <number>', 'Total tokens for velocity tracking', parseInt)
  .option('-s, --status <status>', 'Status override (active|blocked|completed|idle)')
  .action(async (alias, message, options) => {
    const { quickReport } = await import('./commands/quickreport.js');
    return quickReport(alias, message, options);
  });

program
  .command('answer <alias> <questionId> <response>')
  .description('Answer a pending question')
  .action(async (...args) => {
    const { answerQuestion } = await import('./commands/answer.js');
    return answerQuestion(...args);
  });

program
  .command('poke <alias>')
  .description('Poke an agent (append instruction)')
  .option('-m, --message <text>', 'Poke message')
  .action(async (...args) => {
    const { pokeAgent } = await import('./commands/poke.js');
    return pokeAgent(...args);
  });

program
  .command('restart <alias>')
  .description('Restart agent service')
  .action(async (alias) => {
    const { restartAgent } = await import('./commands/restart.js');
    return restartAgent(alias);
  });

program
  .command('archive <alias>')
  .description('Archive agent (move to Relieved)')
  .action(async (alias) => {
    const { archiveAgent } = await import('./commands/archive.js');
    return archiveAgent(alias);
  });

program
  .command('unarchive <alias>')
  .description('Unarchive agent (back to On Assignment)')
  .action(async (alias) => {
    const { unarchiveAgent } = await import('./commands/archive.js');
    return unarchiveAgent(alias);
  });

program
  .command('change-duty <alias> <status>')
  .description('Change duty status (onDuty or offDuty)')
  .action(async (...args) => {
    const { changeDutyStatus } = await import('./commands/change-duty.js');
    return changeDutyStatus(...args);
  });

program
  .command('logs <alias>')
  .description('Tail agent logs')
  .option('--error', 'Show error log instead')
  .action(async (...args) => {
    const { viewLogs } = await import('./commands/logs.js');
    return viewLogs(...args);
  });

program
  .command('word-report <alias>')
  .description('Submit word report after task completion')
  .requiredOption('--status <status>', 'Task status: success, failed, or partial')
  .requiredOption('--summary <text>', 'Summary of task completion')
  .option('--next <time>', 'Next expected trigger time (ISO8601)')
  .option('--trigger-type <type>', 'Trigger type: cron, external, manual, dependency')
  .action(async (alias, options) => {
    const { submitWordReport } = await import('./commands/word-report.js');
    return submitWordReport(alias, options);
  });

program
  .command('check-derrelict <alias>')
  .description('Check if agent is derrelict (strict mode)')
  .action(async (alias) => {
    const { checkDerrelict } = await import('./commands/word-report.js');
    return checkDerrelict(alias);
  });

program
  .command('word-reports <alias>')
  .description('View word report history')
  .option('-n, --limit <number>', 'Number of reports to show', '10')
  .action(async (alias, options) => {
    const { viewWordReports } = await import('./commands/word-report.js');
    return viewWordReports(alias, options);
  });

// Clawdbot gateway management commands
const gateway = program
  .command('gateway')
  .description('Manage Clawdbot gateway (agents run inside gateway)');

gateway
  .command('status')
  .description('Check Clawdbot gateway status')
  .action(async () => {
    const { gatewayStatus } = await import('./commands/gateway.js');
    return gatewayStatus();
  });

gateway
  .command('restart')
  .description('Restart Clawdbot gateway (restarts all agents)')
  .action(async () => {
    const { gatewayRestart } = await import('./commands/gateway.js');
    return gatewayRestart();
  });

gateway
  .command('start')
  .description('Start Clawdbot gateway')
  .action(async () => {
    const { gatewayStart } = await import('./commands/gateway.js');
    return gatewayStart();
  });

gateway
  .command('stop')
  .description('Stop Clawdbot gateway')
  .action(async () => {
    const { gatewayStop } = await import('./commands/gateway.js');
    return gatewayStop();
  });

gateway
  .command('logs')
  .description('Tail Clawdbot gateway logs')
  .action(async () => {
    const { gatewayLogs } = await import('./commands/gateway.js');
    return gatewayLogs();
  });

program.parse();
