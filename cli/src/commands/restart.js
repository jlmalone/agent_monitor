#!/usr/bin/env node

import { execSync } from 'child_process';
import chalk from 'chalk';

/**
 * Restart an agent via launchctl
 * Usage: am restart <alias>
 */
export async function restartAgent(alias) {
    try {
        const label = `vision.salient.agent.${alias}`;

        console.log(chalk.blue('↻') + ' Restarting ' + chalk.bold(alias) + '...');

        // Stop service
        try {
            execSync(`launchctl stop ${label}`, { stdio: 'inherit' });
        } catch (err) {
            // Ignore if not running
        }

        // Wait a moment
        await new Promise(resolve => setTimeout(resolve, 1000));

        // Start service
        try {
            execSync(`launchctl start ${label}`, { stdio: 'inherit' });
        } catch (err) {
            console.error(chalk.red('✖ Failed to start service'));
            process.exit(1);
        }

        console.log(chalk.green('✓') + ' ' + chalk.bold(alias) + ' restarted');

    } catch (err) {
        console.error(chalk.red('✖ Failed to restart agent:'), err.message);
        process.exit(1);
    }
}
