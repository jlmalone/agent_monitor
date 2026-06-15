import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { quickReport } from '../src/commands/quickreport.js';
import * as cfg from '../src/lib/config.js';

// Hermetic: point the lib at a throwaway clawd dir via CLAWD_DIR (resolved at
// call time), so tests never read or write the real ~/clawd.
describe('am CLI', () => {
  const alias = 'testbot';
  let root;
  let statePath;

  before(() => {
    root = mkdtempSync(join(tmpdir(), 'clawd-'));
    process.env.CLAWD_DIR = root;
    writeFileSync(
      join(root, 'agent-registry.json'),
      JSON.stringify({ version: '1.0.0', agents: [{ id: 't-1', alias, persona: 'x', mandate: 'y', enabled: true }] })
    );
    mkdirSync(join(root, 'agents', alias), { recursive: true });
    statePath = join(root, 'agents', alias, 'state.json');
  });

  after(() => {
    delete process.env.CLAWD_DIR;
    if (root) rmSync(root, { recursive: true, force: true });
  });

  beforeEach(() => {
    writeFileSync(statePath, JSON.stringify({ agent: alias.toUpperCase(), alias, status: 'idle', progress: [] }));
  });

  describe('config lib', () => {
    it('resolves agents dir + state path under CLAWD_DIR', () => {
      assert.ok(cfg.getAgentsDir().startsWith(root));
      assert.strictEqual(cfg.getStatePath(alias), statePath);
    });

    it('loadRegistry reads the registry', async () => {
      const reg = await cfg.loadRegistry();
      assert.strictEqual(reg.agents.length, 1);
      assert.strictEqual(reg.agents[0].alias, alias);
    });

    it('loadAgentState returns null for an unknown alias', async () => {
      assert.strictEqual(await cfg.loadAgentState('does-not-exist'), null);
    });
  });

  describe('quickReport()', () => {
    it('updates status, assignment, progress, and lastActivity', async () => {
      await quickReport(alias, 'doing the thing');
      const s = JSON.parse(readFileSync(statePath, 'utf-8'));
      assert.strictEqual(s.status, 'active');
      assert.strictEqual(s.currentAssignment, 'doing the thing');
      assert.ok(s.progress.includes('doing the thing'));
      assert.ok(typeof s.lastActivity === 'number' && s.lastActivity > 0);
    });

    it('honors a status override', async () => {
      await quickReport(alias, 'blocked on X', { status: 'blocked' });
      const s = JSON.parse(readFileSync(statePath, 'utf-8'));
      assert.strictEqual(s.status, 'blocked');
    });

    it('records a token sample', async () => {
      await quickReport(alias, 'work', { tokens: 12345 });
      const s = JSON.parse(readFileSync(statePath, 'utf-8'));
      assert.strictEqual(s.totalTokens, 12345);
      assert.ok(Array.isArray(s.tokenSamples) && s.tokenSamples.length === 1);
      assert.strictEqual(s.tokenSamples[0].totalTokens, 12345);
    });

    it('caps progress history at 50 entries', async () => {
      for (let i = 0; i < 55; i++) await quickReport(alias, `step ${i}`);
      const s = JSON.parse(readFileSync(statePath, 'utf-8'));
      assert.strictEqual(s.progress.length, 50);
      assert.strictEqual(s.progress.at(-1), 'step 54');
    });
  });
});
