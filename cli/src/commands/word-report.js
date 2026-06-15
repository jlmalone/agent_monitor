#!/usr/bin/env node

import { readFile, writeFile } from 'fs/promises';
import { join } from 'path';
import chalk from 'chalk';
import { getAgentsDir, loadAgentState, getStatePath } from '../lib/config.js';
import { v4 as uuidv4 } from 'uuid';

/**
 * Submit a word report for an agent after task completion
 * Usage: am word-report <alias> --status <success|failed> --summary "..." [--next <time>] [--trigger-type <type>]
 */
export async function submitWordReport(alias, options) {
    try {
        const agentsDir = getAgentsDir();
        const wordReportPath = join(agentsDir, alias, 'word-report.md');
        const statePath = getStatePath(alias);

        // Validate required options
        if (!options.status || !['success', 'failed', 'partial'].includes(options.status)) {
            console.error(chalk.red('✖ --status must be one of: success, failed, partial'));
            process.exit(1);
        }

        if (!options.summary) {
            console.error(chalk.red('✖ --summary is required'));
            process.exit(1);
        }

        // Create word report object
        const report = {
            id: uuidv4(),
            timestamp: new Date().toISOString(),
            status: options.status,
            summary: options.summary,
            nextTrigger: options.next ? new Date(options.next).toISOString() : null,
            triggerType: options.triggerType || null
        };

        // Load existing history
        let history = { reports: [] };
        try {
            const existing = await readFile(wordReportPath, 'utf-8');
            history = JSON.parse(existing);
        } catch (err) {
            // File doesn't exist yet, start fresh
        }

        // Append new report
        history.reports.push(report);

        // Keep last 100 reports
        if (history.reports.length > 100) {
            history.reports = history.reports.slice(-100);
        }

        // Write updated history
        await writeFile(wordReportPath, JSON.stringify(history, null, 2));

        // Update agent state
        const state = await loadAgentState(alias);
        if (state) {
            state.lastWordReport = report.timestamp;
            state.lastTaskStatus = report.status;
            if (report.nextTrigger) {
                state.nextExpectedTrigger = report.nextTrigger;
            }

            await writeFile(statePath, JSON.stringify(state, null, 2));
        }

        // Display confirmation
        const statusColor = report.status === 'success' ? chalk.green :
                           report.status === 'failed' ? chalk.red :
                           chalk.yellow;

        console.log(chalk.green('✓') + ' Word report submitted for ' + chalk.bold(alias));
        console.log('  Status: ' + statusColor(report.status));
        console.log('  Summary: ' + report.summary);
        if (report.nextTrigger) {
            console.log('  Next Trigger: ' + chalk.cyan(report.nextTrigger));
        }

    } catch (err) {
        console.error(chalk.red('✖ Failed to submit word report:'), err.message);
        process.exit(1);
    }
}

/**
 * Check if an agent is derrelict (strict mode)
 * Usage: am check-derrelict <alias>
 */
export async function checkDerrelict(alias) {
    try {
        const state = await loadAgentState(alias);

        if (!state) {
            console.log(chalk.red('✖ Agent not found:'), alias);
            process.exit(1);
        }

        // Only Off Duty agents can be derrelict
        if (state.dutyStatus !== 'offDuty') {
            console.log(chalk.green('✓'), alias, 'is On Duty - cannot be derrelict');
            return;
        }

        // Failed without word report = Derrelict
        if (state.lastTaskStatus === 'failed' && !state.lastWordReport) {
            console.log(chalk.red('✖ DERRELICT:'), alias, '- Failed without word report');
            return;
        }

        // Failed with old word report (> 1 hour ago) = Derrelict
        if (state.lastTaskStatus === 'failed' && state.lastWordReport) {
            const reportAge = Date.now() - new Date(state.lastWordReport).getTime();
            const oneHour = 60 * 60 * 1000;

            if (reportAge > oneHour) {
                const hoursAgo = (reportAge / oneHour).toFixed(1);
                console.log(chalk.red('✖ DERRELICT:'), alias, `- Failed with stale word report (${hoursAgo}h ago)`);
                return;
            }
        }

        // Not derrelict
        console.log(chalk.green('✓'), alias, 'is not derrelict');

    } catch (err) {
        console.error(chalk.red('✖ Failed to check derrelict status:'), err.message);
        process.exit(1);
    }
}

/**
 * View word report history for an agent
 * Usage: am word-reports <alias> [--limit <n>]
 */
export async function viewWordReports(alias, options) {
    try {
        const agentsDir = getAgentsDir();
        const wordReportPath = join(agentsDir, alias, 'word-report.md');

        const data = await readFile(wordReportPath, 'utf-8');
        const history = JSON.parse(data);

        const limit = options.limit ? parseInt(options.limit) : 10;
        const reports = history.reports.slice(-limit).reverse();

        if (reports.length === 0) {
            console.log(chalk.yellow('No word reports found for'), alias);
            return;
        }

        console.log(chalk.bold('\nWord Reports for'), chalk.cyan(alias));
        console.log(chalk.gray('─'.repeat(60)));

        reports.forEach((report, index) => {
            const statusColor = report.status === 'success' ? chalk.green :
                               report.status === 'failed' ? chalk.red :
                               chalk.yellow;

            const timestamp = new Date(report.timestamp);
            const timeAgo = getTimeAgo(timestamp);

            console.log(`\n${statusColor('●')} ${statusColor(report.status.toUpperCase())} - ${timeAgo}`);
            console.log(`  ${report.summary}`);
            if (report.nextTrigger) {
                console.log(`  Next: ${chalk.cyan(new Date(report.nextTrigger).toLocaleString())}`);
            }
        });

        console.log('\n');

    } catch (err) {
        if (err.code === 'ENOENT') {
            console.log(chalk.yellow('No word reports found for'), alias);
        } else {
            console.error(chalk.red('✖ Failed to view word reports:'), err.message);
            process.exit(1);
        }
    }
}

/**
 * Helper: Get human-readable time ago
 */
function getTimeAgo(date) {
    const seconds = Math.floor((Date.now() - date.getTime()) / 1000);

    if (seconds < 60) return `${seconds}s ago`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    return `${Math.floor(seconds / 86400)}d ago`;
}
