#!/usr/bin/env node

/**
 * Migration Script: Add new fields to agent states
 * Run this to migrate existing agent states to the enhanced data model
 */

import { readFile, writeFile, readdir } from 'fs/promises';
import { join } from 'path';
import { homedir } from 'os';

const AGENTS_DIR = join(homedir(), 'clawd/agents');

async function migrateAgentState(alias) {
    const statePath = join(AGENTS_DIR, alias, 'state.json');

    try {
        // Read existing state
        const data = await readFile(statePath, 'utf-8');
        const state = JSON.parse(data);

        // Add new fields if missing
        if (!state.assignmentStatus) {
            state.assignmentStatus = 'onAssignment';
        }

        if (!state.dutyStatus) {
            state.dutyStatus = 'onDuty';
        }

        if (!state.lastWordReport) {
            state.lastWordReport = null;
        }

        if (!state.nextExpectedTrigger) {
            state.nextExpectedTrigger = null;
        }

        if (!state.lastTaskStatus) {
            state.lastTaskStatus = null;
        }

        // Write updated state
        await writeFile(statePath, JSON.stringify(state, null, 2));

        console.log(`✓ Migrated ${alias}`);

        return true;

    } catch (err) {
        if (err.code === 'ENOENT') {
            console.log(`⚠ No state.json for ${alias}`);
            return false;
        }

        console.error(`✖ Failed to migrate ${alias}:`, err.message);
        return false;
    }
}

async function createInitialWordReport(alias) {
    const wordReportPath = join(AGENTS_DIR, alias, 'word-report.md');

    try {
        // Check if file exists
        await readFile(wordReportPath, 'utf-8');
        console.log(`  Word report already exists for ${alias}`);
        return true;

    } catch (err) {
        if (err.code === 'ENOENT') {
            // Create initial empty history
            const history = {
                reports: []
            };

            await writeFile(wordReportPath, JSON.stringify(history, null, 2));
            console.log(`  Created word-report.md for ${alias}`);
            return true;
        }

        console.error(`  ✖ Failed to create word report for ${alias}:`, err.message);
        return false;
    }
}

async function migrateRegistry() {
    const registryPath = join(homedir(), 'clawd/agent-registry.json');

    try {
        const data = await readFile(registryPath, 'utf-8');
        const registry = JSON.parse(data);

        let modified = false;

        for (const agent of registry.agents) {
            // Add new fields if missing (though registry doesn't store these yet)
            // This is for future expansion

            if (!agent.metadata) {
                agent.metadata = {};
            }

            modified = true;
        }

        if (modified) {
            await writeFile(registryPath, JSON.stringify(registry, null, 2));
            console.log('✓ Migrated agent registry');
        }

    } catch (err) {
        console.error('✖ Failed to migrate registry:', err.message);
    }
}

async function main() {
    console.log('🔧 Agent Monitor Data Migration\n');

    // Migrate registry
    await migrateRegistry();
    console.log('');

    // Get all agent directories
    const agents = await readdir(AGENTS_DIR);

    console.log(`Found ${agents.length} agents\n`);

    // Migrate each agent
    for (const alias of agents) {
        await migrateAgentState(alias);
        await createInitialWordReport(alias);
    }

    console.log('\n✅ Migration complete!\n');
}

main().catch(err => {
    console.error('✖ Migration failed:', err.message);
    process.exit(1);
});
