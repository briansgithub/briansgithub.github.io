#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { createInterface } from 'node:readline/promises';
import { fileURLToPath } from 'node:url';

const WEBSITE_ROOT = fileURLToPath(new URL('../..', import.meta.url));
const EXPECTED_TOOLS_PACKAGE = 'personal-website-authoring-tools';

function resolveToolsRoot() {
	const override = process.env.PERSONAL_AUTHORING_TOOLS_ROOT?.trim();
	const candidate = override
		? path.resolve(override)
		: path.resolve(WEBSITE_ROOT, '..', 'personal-website-authoring-tools');
	let packageData;
	try {
		packageData = JSON.parse(readFileSync(path.join(candidate, 'package.json'), 'utf8'));
	} catch (error) {
		throw new Error(
			`Could not open the authoring tools at ${candidate}. Set PERSONAL_AUTHORING_TOOLS_ROOT to that directory. ${error.message}`,
		);
	}
	if (packageData.name !== EXPECTED_TOOLS_PACKAGE) {
		throw new Error(`The directory at ${candidate} is not ${EXPECTED_TOOLS_PACKAGE}.`);
	}
	return candidate;
}

function parseAction(argv) {
	const tokens = argv.filter((token) => !token.startsWith('-'));
	const first = (tokens[0] || '').toLowerCase();
	if (['write', 'author', '1'].includes(first)) return 'write';
	if (['publish', 'review', '2'].includes(first)) return 'publish';
	return null;
}

async function chooseAction() {
	if (!process.stdin.isTTY || !process.stdout.isTTY) return 'write';
	const prompt = createInterface({ input: process.stdin, output: process.stdout });
	try {
		console.log('Website authoring (via personal-website-authoring-tools)');
		console.log('  1. Write — open Authoring Home');
		console.log('  2. Publish — review, verify, and push');
		const answer = (await prompt.question('Choose 1 or 2 [1]: ')).trim();
		if (answer === '2' || /^p/i.test(answer)) return 'publish';
		return 'write';
	} finally {
		prompt.close();
	}
}

function runTools(toolsRoot, action) {
	const script = action === 'publish' ? 'publish:content' : 'author';
	const extra =
		action === 'publish' ? process.argv.slice(2).filter((token) => token.startsWith('-')) : [];
	const result = spawnSync('npm', ['run', script, '--', ...extra], {
		cwd: toolsRoot,
		stdio: 'inherit',
		shell: true,
		windowsHide: true,
	});
	if (result.error) throw result.error;
	return result.status ?? 1;
}

async function main() {
	if (process.argv.includes('--help') || process.argv.includes('-h')) {
		console.log(`Launch the unified authoring tools from the website checkout.

Usage:
  npm run content:workflow
  npm run content:workflow -- write
  npm run content:workflow -- publish

The tools live in the sibling personal-website-authoring-tools directory, or
PERSONAL_AUTHORING_TOOLS_ROOT.`);
		return;
	}
	if (process.argv.some((token) => /^-/.test(token) && /diagnostics|whatif/i.test(token))) {
		console.log(
			'Diagnostics and WhatIf now live in the authoring tools: npm run author:status, npm run content:status, and npm run publish:content -- --dry-run.',
		);
	}
	const toolsRoot = resolveToolsRoot();
	const action = parseAction(process.argv.slice(2)) || (await chooseAction());
	process.exitCode = runTools(toolsRoot, action);
}

main().catch((error) => {
	console.error(error.message);
	process.exitCode = 1;
});
