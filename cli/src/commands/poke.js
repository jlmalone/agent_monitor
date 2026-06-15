#!/usr/bin/env node

import { writeFile, readFile } from 'fs/promises';
import { join } from 'path';
import chalk from 'chalk';
import { getAgentsDir } from '../lib/config.js';

/**
 * Poke an agent (append instruction to instructions.md)
 * Usage: am poke <alias> [--message "text"]
 */
export async function pokeAgent(alias, options) {
    try {
        const agentsDir = getAgentsDir();
        const instructionsPath = join(agentsDir, alias, 'instructions.md');

        const timestamp = new Date().toISOString();
        const defaultMessage = "Checking in. Status update requested.";
        const message = options.message || defaultMessage;

        const content = `## Poke [${timestamp}]\n\n${message}\n\n---\n\n`;

        // Prepend to existing file or create new
        let existing = '';
        try {
            existing = await readFile(instructionsPath, 'utf-8');
        } catch (err) {
            // File doesn't exist yet
        }

        await writeFile(instructionsPath, content + existing);

        console.log(chalk.green('✓') + ' Poked ' + chalk.bold(alias));
        console.log('  Message: ' + message);

    } catch (err) {
        console.error(chalk.red('✖ Failed to poke agent:'), err.message);
        process.exit(1);
    }
}
