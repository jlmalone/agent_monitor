#!/usr/bin/env node

import chalk from 'chalk';
import { loadRegistry } from '../lib/config.js';
import {
    installService,
    uninstallService,
    startService,
    stopService,
    restartService,
    installAllServices,
    listServices,
    getServiceStatus
} from '../lib/launchd.js';

/**
 * Install service for agent
 * Usage: am service install <alias>
 */
export async function installAgentService(alias, options) {
    try {
        const registry = await loadRegistry();
        const agent = registry.agents.find(a => a.alias === alias);

        if (!agent) {
            console.error(chalk.red('✖ Agent not found:'), alias);
            process.exit(1);
        }

        await installService(agent);

    } catch (err) {
        console.error(chalk.red('✖'), err.message);
        process.exit(1);
    }
}

/**
 * Uninstall service for agent
 * Usage: am service uninstall <alias>
 */
export async function uninstallAgentService(alias, options) {
    try {
        const registry = await loadRegistry();
        const agent = registry.agents.find(a => a.alias === alias);

        if (!agent) {
            console.error(chalk.red('✖ Agent not found:'), alias);
            process.exit(1);
        }

        await uninstallService(agent);

    } catch (err) {
        console.error(chalk.red('✖'), err.message);
        process.exit(1);
    }
}

/**
 * Start agent service
 * Usage: am service start <alias>
 */
export async function startAgentService(alias, options) {
    try {
        startService(alias);
    } catch (err) {
        console.error(chalk.red('✖'), err.message);
        process.exit(1);
    }
}

/**
 * Stop agent service
 * Usage: am service stop <alias>
 */
export async function stopAgentService(alias, options) {
    try {
        stopService(alias);
    } catch (err) {
        console.error(chalk.red('✖'), err.message);
        process.exit(1);
    }
}

/**
 * Restart agent service
 * Usage: am service restart <alias>
 */
export async function restartAgentService(alias, options) {
    try {
        restartService(alias);
    } catch (err) {
        console.error(chalk.red('✖'), err.message);
        process.exit(1);
    }
}

/**
 * Install all enabled services
 * Usage: am service install-all
 */
export async function installAll(options) {
    try {
        const registry = await loadRegistry();
        await installAllServices(registry);
    } catch (err) {
        console.error(chalk.red('✖'), err.message);
        process.exit(1);
    }
}

/**
 * List all services
 * Usage: am service list
 */
export async function listAllServices(options) {
    try {
        const registry = await loadRegistry();
        listServices(registry);
    } catch (err) {
        console.error(chalk.red('✖'), err.message);
        process.exit(1);
    }
}

/**
 * Get service status
 * Usage: am service status <alias>
 */
export async function getAgentServiceStatus(alias, options) {
    try {
        const status = getServiceStatus(alias);

        console.log(chalk.bold('\nService Status:'), alias);
        console.log('  Label:', status.label);
        console.log('  Running:', status.running ? chalk.green('Yes') : chalk.red('No'));

        if (status.running) {
            console.log('  PID:', chalk.cyan(status.pid));
        }

        if (status.exitStatus !== null && status.exitStatus !== 0) {
            console.log('  Exit Status:', chalk.red(status.exitStatus));
        }

        console.log('');

    } catch (err) {
        console.error(chalk.red('✖'), err.message);
        process.exit(1);
    }
}
