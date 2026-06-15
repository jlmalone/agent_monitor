#!/usr/bin/env node

import { spawn } from 'child_process';
import { homedir } from 'os';
import { join } from 'path';
import chalk from 'chalk';

/**
 * Tail agent logs
 * Usage: am logs <alias> [--error]
 */
export async function viewLogs(alias, options) {
    const logDir = join(homedir(), 'ios_code', 'agent_monitor', 'logs');
    const logFile = options.error ?
        join(logDir, `${alias}.error.log`) :
        join(logDir, `${alias}.log`);

    console.log(chalk.blue('📋 Tailing logs for') + ' ' + chalk.bold(alias));
    console.log(chalk.gray('Log file:'), logFile);
    console.log(chalk.gray('Press Ctrl+C to stop\n'));

    // Use tail to follow logs
    const tail = spawn('tail', ['-f', logFile], {
        stdio: 'inherit'
    });

    tail.on('error', (err) => {
        if (err.code === 'ENOENT') {
            console.error(chalk.red('✖ Log file not found:'), logFile);
        } else {
            console.error(chalk.red('✖ Failed to tail logs:'), err.message);
        }
        process.exit(1);
    });

    // Handle Ctrl+C gracefully
    process.on('SIGINT', () => {
        tail.kill();
        console.log('\n' + chalk.gray('Stopped tailing logs'));
        process.exit(0);
    });
}
