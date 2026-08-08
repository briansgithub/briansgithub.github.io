#!/usr/bin/env node

import { access, lstat, readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = fileURLToPath(new URL('../', import.meta.url));
const SOURCE_ROOT = path.join(REPO_ROOT, 'src');
const PUBLIC_ROOT = path.join(REPO_ROOT, 'public');
const DIST_ROOT = path.join(REPO_ROOT, 'dist');

function usage() {
	console.log(`Check local links without making network requests.

Usage:
  node scripts/check-links.mjs [source|dist]

source (default) checks Markdown/MDX asset links and rejects Obsidian wikilinks.
dist checks local href/src/srcset targets in the generated HTML and CSS.`);
}

async function exists(candidate) {
	try {
		await access(candidate);
		return true;
	} catch {
		return false;
	}
}

async function collectFiles(directory, predicate) {
	const files = [];
	async function walk(current) {
		let entries;
		try {
			entries = await readdir(current, { withFileTypes: true });
		} catch (error) {
			if (error.code === 'ENOENT') return;
			throw error;
		}
		for (const entry of entries) {
			const absolute = path.join(current, entry.name);
			if (entry.isDirectory()) await walk(absolute);
			else if (entry.isFile() && predicate(absolute)) files.push(absolute);
		}
	}
	await walk(directory);
	return files.sort();
}

function cleanTarget(raw) {
	let target = raw.trim();
	if (target.startsWith('<') && target.endsWith('>')) target = target.slice(1, -1);
	target = target.split(/\s+["']/)[0];
	try {
		target = decodeURIComponent(target);
	} catch {
		// Keep the original so the eventual error points at the authored value.
	}
	return target;
}

function skipTarget(target) {
	return (
		!target ||
		target.startsWith('#') ||
		target.startsWith('//') ||
		/^[a-z][a-z0-9+.-]*:/i.test(target) ||
		/[{}$]/.test(target)
	);
}

function stripQueryAndHash(target) {
	return target.split('#', 1)[0].split('?', 1)[0];
}

function markdownTargets(contents) {
	const found = [];
	const inline = /!?\[[^\]]*\]\(([^)]+)\)/g;
	const reference = /^\s*\[[^\]]+\]:\s*(\S+)/gm;
	const html = /\b(?:href|src)\s*=\s*["']([^"']+)["']/gi;
	for (const regex of [inline, reference, html]) {
		let match;
		while ((match = regex.exec(contents))) found.push(cleanTarget(match[1]));
	}
	return found;
}

function htmlTargets(contents) {
	const found = [];
	const simple = /\b(?:href|src)\s*=\s*["']([^"']+)["']/gi;
	let match;
	while ((match = simple.exec(contents))) found.push(cleanTarget(match[1]));

	const srcset = /\bsrcset\s*=\s*["']([^"']+)["']/gi;
	while ((match = srcset.exec(contents))) {
		for (const candidate of match[1].split(',')) {
			found.push(cleanTarget(candidate.trim().split(/\s+/, 1)[0]));
		}
	}

	const cssUrl = /\burl\(\s*["']?([^)'"\s]+)["']?\s*\)/gi;
	while ((match = cssUrl.exec(contents))) found.push(cleanTarget(match[1]));
	return found;
}

function isWithin(parent, candidate) {
	const relative = path.relative(parent, candidate);
	return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
}

async function sourceTargetExists(sourceFile, rawTarget) {
	const target = stripQueryAndHash(rawTarget);
	if (!target) return true;

	if (target.startsWith('/')) {
		const relative = target.replace(/^\/+/, '');
		if (await exists(path.join(PUBLIC_ROOT, relative))) return true;
		if (relative.startsWith('src/') && (await exists(path.join(REPO_ROOT, relative)))) return true;
		// Root-relative extensionless targets are site routes, validated after build.
		return path.extname(relative) === '';
	}

	const candidate = path.resolve(path.dirname(sourceFile), target);
	if (!isWithin(REPO_ROOT, candidate)) return false;
	if (await exists(candidate)) return true;
	// Extensionless content links are route-like and are validated in dist mode.
	return path.extname(target) === '';
}

async function distTargetExists(sourceFile, rawTarget) {
	const target = stripQueryAndHash(rawTarget);
	if (!target) return true;
	const candidate = target.startsWith('/')
		? path.join(DIST_ROOT, target.replace(/^\/+/, ''))
		: path.resolve(path.dirname(sourceFile), target);

	if (!isWithin(DIST_ROOT, candidate)) return false;

	if (await exists(candidate)) {
		const info = await lstat(candidate);
		if (info.isDirectory()) return exists(path.join(candidate, 'index.html'));
		return true;
	}
	if (await exists(`${candidate}.html`)) return true;
	if (await exists(path.join(candidate, 'index.html'))) return true;
	return false;
}

async function checkSource() {
	const files = await collectFiles(SOURCE_ROOT, (file) => /\.mdx?$/i.test(file));
	const errors = [];

	for (const file of files) {
		const contents = await readFile(file, 'utf8');
		const wikilinks = contents.match(/!?\[\[[^\]]+\]\]/g) || [];
		for (const link of wikilinks) {
			errors.push(`${path.relative(REPO_ROOT, file)}: unsupported Obsidian link ${link}`);
		}

		for (const target of markdownTargets(contents)) {
			if (skipTarget(target)) continue;
			if (!(await sourceTargetExists(file, target))) {
				errors.push(`${path.relative(REPO_ROOT, file)}: missing local target ${target}`);
			}
		}
	}

	return { checked: files.length, errors };
}

async function checkDist() {
	if (!(await exists(DIST_ROOT)))
		throw new Error('dist/ does not exist. Run the Astro build first.');
	const files = await collectFiles(DIST_ROOT, (file) => /\.(?:html|css)$/i.test(file));
	const errors = [];

	for (const file of files) {
		const contents = await readFile(file, 'utf8');
		for (const target of htmlTargets(contents)) {
			if (skipTarget(target)) continue;
			if (!(await distTargetExists(file, target))) {
				errors.push(`${path.relative(REPO_ROOT, file)}: missing built target ${target}`);
			}
		}
	}
	return { checked: files.length, errors };
}

async function main() {
	const mode = process.argv[2] || 'source';
	if (['--help', '-h'].includes(mode)) {
		usage();
		return;
	}
	if (!['source', 'dist'].includes(mode)) throw new Error('Mode must be source or dist.');

	const result = mode === 'source' ? await checkSource() : await checkDist();
	if (result.errors.length > 0) {
		console.error(
			`Link check failed (${result.errors.length} problem${result.errors.length === 1 ? '' : 's'}):`,
		);
		for (const error of result.errors) console.error(`- ${error}`);
		process.exitCode = 1;
		return;
	}
	console.log(
		`Link check passed (${mode}; ${result.checked} file${result.checked === 1 ? '' : 's'} checked).`,
	);
}

main().catch((error) => {
	console.error(`check-links: ${error.message}`);
	process.exitCode = 1;
});
