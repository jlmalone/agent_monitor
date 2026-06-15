#!/usr/bin/env node

import { readFile, writeFile } from 'fs/promises';
import chalk from 'chalk';
import { loadAgentState, getStatePath } from '../lib/config.js';

/**
 * Archive an agent (move to Relieved status)
 * Usage: am archive <alias>
 */
export async function archiveAgent(alias) {
    try {
        const state = await loadAgentState(alias);

        if (!state) {
            console.error(chalk.red('✖ Agent not found:'), alias);
            process.exit(1);
        }

        // Update assignment status
        state.assignmentStatus = 'relieved';

        const statePath = getStatePath(alias);
        await writeFile(statePath, JSON.stringify(state, null, 2));

        console.log(chalk.green('✓') + ' Archived ' + chalk.bold(alias));
        console.log('  Status: ' + chalk.gray('Relieved'));

    } catch (err) {
        console.error(chalk.red('✖ Failed to archive agent:'), err.message);
        process.exit(1);
    }
}

/**
 * Unarchive an agent (move back to On Assignment)
 * Usage: am unarchive <alias>
 */
export async function unarchiveAgent(alias) {
    try {
        const state = await loadAgentState(alias);

        if (!state) {
            console.error(chalk.red('✖ Agent not found:'), alias);
            process.exit(1);
        }

        // Update assignment status
        state.assignmentStatus = 'onAssignment';

        const statePath = getStatePath(alias);
        await writeFile(statePath, JSON.stringify(state, null, 2));

        console.log(chalk.green('✓') + ' Unarchived ' + chalk.bold(alias));
        console.log('  Status: ' + chalk.green('On Assignment'));

    } catch (err) {
        console.error(chalk.red('✖ Failed to unarchive agent:'), err.message);
        process.exit(1);
    }
}
