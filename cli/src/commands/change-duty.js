#!/usr/bin/env node

import { writeFile } from 'fs/promises';
import chalk from 'chalk';
import { loadAgentState, getStatePath } from '../lib/config.js';

/**
 * Change agent duty status
 * Usage: am change-duty <alias> <onDuty|offDuty>
 */
export async function changeDutyStatus(alias, dutyStatus) {
    try {
        // Validate duty status
        if (!['onDuty', 'offDuty'].includes(dutyStatus)) {
            console.error(chalk.red('✖ Duty status must be: onDuty or offDuty'));
            process.exit(1);
        }

        const state = await loadAgentState(alias);

        if (!state) {
            console.error(chalk.red('✖ Agent not found:'), alias);
            process.exit(1);
        }

        // Update duty status
        state.dutyStatus = dutyStatus;

        const statePath = getStatePath(alias);
        await writeFile(statePath, JSON.stringify(state, null, 2));

        const statusColor = dutyStatus === 'onDuty' ? chalk.green : chalk.gray;

        console.log(chalk.green('✓') + ' Changed duty status for ' + chalk.bold(alias));
        console.log('  Duty: ' + statusColor(dutyStatus === 'onDuty' ? 'On Duty' : 'Off Duty'));

    } catch (err) {
        console.error(chalk.red('✖ Failed to change duty status:'), err.message);
        process.exit(1);
    }
}
