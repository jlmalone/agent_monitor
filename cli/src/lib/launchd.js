#!/usr/bin/env node

import { readFile, writeFile, unlink } from 'fs/promises';
import { homedir } from 'os';
import { join } from 'path';
import { execSync } from 'child_process';
import chalk from 'chalk';

const LAUNCHAGENTS_DIR = join(homedir(), 'Library/LaunchAgents');
const LOG_DIR = join(homedir(), 'ios_code/agent_monitor/logs');
const TEMPLATE_PATH = join(process.cwd(), 'launchd/vision.salient.agent.template.plist');

/**
 * Generate launchd plist for an agent
 */
export async function generatePlist(agent) {
    try {
        // Load template
        const template = await readFile(TEMPLATE_PATH, 'utf-8');

        // Get API key from environment
        const apiKey = process.env.ANTHROPIC_API_KEY || '';
        if (!apiKey) {
            console.warn(chalk.yellow('⚠ ANTHROPIC_API_KEY not set in environment'));
        }

        // Replace placeholders
        const plist = template
            .replace(/\{LABEL\}/g, `vision.salient.agent.${agent.alias}`)
            .replace(/\{ALIAS\}/g, agent.alias)
            .replace(/\{WORK_DIR\}/g, agent.workDir.replace('~', homedir()))
            .replace(/\{API_KEY\}/g, apiKey)
            .replace(/\{HOME\}/g, homedir())
            .replace(/\{LOG_DIR\}/g, LOG_DIR);

        return plist;

    } catch (err) {
        throw new Error(`Failed to generate plist: ${err.message}`);
    }
}

/**
 * Install agent service
 */
export async function installService(agent) {
    try {
        const label = `vision.salient.agent.${agent.alias}`;
        const plistPath = join(LAUNCHAGENTS_DIR, `${label}.plist`);

        console.log(chalk.blue('⚙') + ' Installing service for ' + chalk.bold(agent.alias));

        // Generate plist
        const plist = await generatePlist(agent);

        // Write to LaunchAgents
        await writeFile(plistPath, plist);

        // Load service
        try {
            execSync(`launchctl load "${plistPath}"`, { stdio: 'pipe' });
        } catch (err) {
            // Ignore if already loaded
        }

        // Start service (will auto-start via RunAtLoad, but force start now)
        try {
            execSync(`launchctl start ${label}`, { stdio: 'pipe' });
        } catch (err) {
            console.warn(chalk.yellow('⚠ Service may already be running'));
        }

        console.log(chalk.green('✓') + ' Service installed: ' + chalk.bold(agent.alias));

        // Check status
        const status = getServiceStatus(agent.alias);
        if (status.running) {
            console.log('  Status: ' + chalk.green('Running') + ` (PID: ${status.pid})`);
        } else {
            console.log('  Status: ' + chalk.red('Stopped'));
        }

    } catch (err) {
        throw new Error(`Failed to install service: ${err.message}`);
    }
}

/**
 * Uninstall agent service
 */
export async function uninstallService(agent) {
    try {
        const label = `vision.salient.agent.${agent.alias}`;
        const plistPath = join(LAUNCHAGENTS_DIR, `${label}.plist`);

        console.log(chalk.blue('⚙') + ' Uninstalling service for ' + chalk.bold(agent.alias));

        // Stop service
        try {
            execSync(`launchctl stop ${label}`, { stdio: 'pipe' });
        } catch (err) {
            // Ignore if not running
        }

        // Unload service
        try {
            execSync(`launchctl unload "${plistPath}"`, { stdio: 'pipe' });
        } catch (err) {
            // Ignore if not loaded
        }

        // Remove plist
        try {
            await unlink(plistPath);
        } catch (err) {
            // Ignore if doesn't exist
        }

        console.log(chalk.green('✓') + ' Service uninstalled: ' + chalk.bold(agent.alias));

    } catch (err) {
        throw new Error(`Failed to uninstall service: ${err.message}`);
    }
}

/**
 * Get service status
 */
export function getServiceStatus(alias) {
    const label = `vision.salient.agent.${alias}`;

    try {
        const output = execSync(`launchctl list | grep ${label}`, {
            encoding: 'utf8',
            stdio: 'pipe'
        });

        const [pid, exitStatus, _] = output.trim().split(/\s+/);

        return {
            running: pid !== '-',
            pid: pid !== '-' ? parseInt(pid) : null,
            exitStatus: exitStatus !== '-' ? parseInt(exitStatus) : null,
            label
        };
    } catch (err) {
        return {
            running: false,
            pid: null,
            exitStatus: null,
            label
        };
    }
}

/**
 * Start service
 */
export function startService(alias) {
    const label = `vision.salient.agent.${alias}`;

    try {
        execSync(`launchctl start ${label}`, { stdio: 'pipe' });
        console.log(chalk.green('✓') + ' Started ' + chalk.bold(alias));

        // Check status after brief delay
        setTimeout(() => {
            const status = getServiceStatus(alias);
            if (status.running) {
                console.log('  PID: ' + chalk.cyan(status.pid));
            } else {
                console.log(chalk.yellow('  ⚠ Service failed to start - check logs'));
            }
        }, 1000);

    } catch (err) {
        throw new Error(`Failed to start service: ${err.message}`);
    }
}

/**
 * Stop service
 */
export function stopService(alias) {
    const label = `vision.salient.agent.${alias}`;

    try {
        execSync(`launchctl stop ${label}`, { stdio: 'pipe' });
        console.log(chalk.green('✓') + ' Stopped ' + chalk.bold(alias));
    } catch (err) {
        throw new Error(`Failed to stop service: ${err.message}`);
    }
}

/**
 * Restart service
 */
export function restartService(alias) {
    console.log(chalk.blue('↻') + ' Restarting ' + chalk.bold(alias) + '...');

    try {
        stopService(alias);
        // Wait a moment
        execSync('sleep 1');
        startService(alias);
    } catch (err) {
        throw new Error(`Failed to restart service: ${err.message}`);
    }
}

/**
 * Install all enabled services
 */
export async function installAllServices(registry) {
    const enabledAgents = registry.agents.filter(a => a.enabled);

    console.log(chalk.bold(`\nInstalling ${enabledAgents.length} services...\n`));

    for (const agent of enabledAgents) {
        try {
            await installService(agent);
        } catch (err) {
            console.error(chalk.red('✖'), agent.alias, '-', err.message);
        }
        console.log(''); // Blank line
    }

    console.log(chalk.green('✓') + ' All services installed\n');
}

/**
 * List all agent services
 */
export function listServices(registry) {
    console.log(chalk.bold('\nAgent Services:\n'));

    for (const agent of registry.agents) {
        const status = getServiceStatus(agent.alias);

        const statusText = status.running ?
            chalk.green('Running') + ` (PID: ${status.pid})` :
            chalk.gray('Stopped');

        console.log(`${status.running ? '●' : '○'} ${chalk.bold(agent.alias).padEnd(20)} ${statusText}`);
    }

    console.log('');
}
