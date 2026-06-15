#!/usr/bin/env node

import { execSync } from 'child_process';
import chalk from 'chalk';

const CLAWDBOT_LABEL = 'com.clawdbot.gateway';

/**
 * Check Clawdbot gateway status
 * Usage: am gateway status
 */
export async function gatewayStatus() {
    try {
        const output = execSync(`launchctl list | grep ${CLAWDBOT_LABEL}`, {
            encoding: 'utf8',
            stdio: 'pipe'
        });

        const [pid, exitStatus, label] = output.trim().split(/\s+/);

        console.log(chalk.bold('\nClawdbot Gateway Status:\n'));
        console.log('  Label:', chalk.cyan(label));
        console.log('  Running:', pid !== '-' ? chalk.green('Yes') : chalk.red('No'));

        if (pid !== '-') {
            console.log('  PID:', chalk.cyan(pid));
        }

        if (exitStatus !== '-' && exitStatus !== '0') {
            console.log('  Exit Status:', chalk.red(exitStatus));
        }

        // Check processes
        try {
            const processes = execSync('ps aux | grep -i clawdbot | grep -v grep', {
                encoding: 'utf8',
                stdio: 'pipe'
            });
            console.log('\n  Processes:');
            processes.split('\n').filter(Boolean).forEach(line => {
                console.log('    ' + chalk.gray(line.substring(0, 120)));
            });
        } catch (e) {
            console.log('  Processes:', chalk.yellow('None running'));
        }

        console.log('');

    } catch (err) {
        console.log(chalk.red('\n✖ Clawdbot gateway is not running\n'));
        console.log('  To start: ' + chalk.cyan('launchctl start ' + CLAWDBOT_LABEL));
        console.log('');
        process.exit(1);
    }
}

/**
 * Restart Clawdbot gateway
 * Usage: am gateway restart
 */
export async function gatewayRestart() {
    try {
        console.log(chalk.blue('↻') + ' Restarting Clawdbot gateway...');

        // Stop
        try {
            execSync(`launchctl stop ${CLAWDBOT_LABEL}`, { stdio: 'inherit' });
            await new Promise(resolve => setTimeout(resolve, 2000));
        } catch (err) {
            // Ignore if not running
        }

        // Start
        execSync(`launchctl start ${CLAWDBOT_LABEL}`, { stdio: 'inherit' });

        await new Promise(resolve => setTimeout(resolve, 2000));

        console.log(chalk.green('✓') + ' Clawdbot gateway restarted');
        console.log('');

        // Show status
        await gatewayStatus();

    } catch (err) {
        console.error(chalk.red('✖ Failed to restart gateway:'), err.message);
        process.exit(1);
    }
}

/**
 * Stop Clawdbot gateway
 * Usage: am gateway stop
 */
export async function gatewayStop() {
    try {
        console.log(chalk.yellow('⏸') + ' Stopping Clawdbot gateway...');

        execSync(`launchctl stop ${CLAWDBOT_LABEL}`, { stdio: 'inherit' });

        console.log(chalk.green('✓') + ' Clawdbot gateway stopped');
        console.log('');

    } catch (err) {
        console.error(chalk.red('✖ Failed to stop gateway:'), err.message);
        process.exit(1);
    }
}

/**
 * Start Clawdbot gateway
 * Usage: am gateway start
 */
export async function gatewayStart() {
    try {
        console.log(chalk.blue('▶') + ' Starting Clawdbot gateway...');

        execSync(`launchctl start ${CLAWDBOT_LABEL}`, { stdio: 'inherit' });

        await new Promise(resolve => setTimeout(resolve, 2000));

        console.log(chalk.green('✓') + ' Clawdbot gateway started');
        console.log('');

        // Show status
        await gatewayStatus();

    } catch (err) {
        console.error(chalk.red('✖ Failed to start gateway:'), err.message);
        process.exit(1);
    }
}

/**
 * View Clawdbot logs
 * Usage: am gateway logs
 */
export async function gatewayLogs() {
    console.log(chalk.blue('📋 Clawdbot Gateway Logs\n'));
    console.log(chalk.gray('Press Ctrl+C to stop\n'));

    const logPath = `${process.env.HOME}/.clawdbot/logs/gateway.log`;

    try {
        execSync(`tail -f "${logPath}"`, { stdio: 'inherit' });
    } catch (err) {
        if (err.code === 'ENOENT') {
            console.error(chalk.red('\n✖ Log file not found:'), logPath);
        }
        process.exit(1);
    }
}
