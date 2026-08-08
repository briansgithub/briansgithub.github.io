#!/usr/bin/env node

import { access, mkdir, readFile, readdir, rename, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { createInterface } from 'node:readline/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = fileURLToPath(new URL('../', import.meta.url));
const CONTENT_ROOT = path.join(REPO_ROOT, 'src', 'content');
const PUBLISHABLE_COLLECTIONS = new Set(['writing', 'projects', 'books', 'quotes', 'pages']);

function usage() {
	console.log(`Validate and explicitly publish one Markdown content file.

Usage:
  node scripts/publish-content.mjs <content-file> [options]
  node scripts/publish-content.mjs --list

Options:
  --check               Validate without changing the file
  --yes                 Skip the interactive confirmation
  --allow-placeholder   Permit placeholder: true content
  --skip-checks         Skip repository asset/link checks after editing
  --list                List files containing draft: true
  --help                Show this help

Private drafts under src/content/_drafts are copied into their collection, validated,
then removed from _drafts. Existing collection drafts are updated in place.
The command never commits or pushes.`);
}

function parseArgs(argv) {
	const options = { positional: [] };
	for (let index = 0; index < argv.length; index += 1) {
		const value = argv[index];
		if (!value.startsWith('--')) {
			options.positional.push(value);
			continue;
		}
		const name = value.slice(2);
		if (['check', 'yes', 'allow-placeholder', 'skip-checks', 'list', 'help'].includes(name)) {
			options[name] = true;
			continue;
		}
		throw new Error(`Unknown option: ${value}`);
	}
	return options;
}

function parseFrontmatter(contents) {
	const match = contents.match(/^---\s*\r?\n([\s\S]*?)\r?\n---\s*(?:\r?\n|$)/);
	if (!match) throw new Error('The file must start with YAML frontmatter enclosed by --- lines.');

	const values = new Map();
	for (const line of match[1].split(/\r?\n/)) {
		const field = line.match(/^([A-Za-z][A-Za-z0-9_-]*):\s*(.*?)\s*$/);
		if (field) values.set(field[1], field[2]);
	}
	return { block: match[0], yaml: match[1], values };
}

function scalar(values, name) {
	const raw = values.get(name);
	if (raw === undefined) return undefined;
	const trimmed = raw.trim();
	if (
		(trimmed.startsWith('"') && trimmed.endsWith('"')) ||
		(trimmed.startsWith("'") && trimmed.endsWith("'"))
	) {
		try {
			return trimmed.startsWith('"')
				? JSON.parse(trimmed)
				: trimmed.slice(1, -1).replace(/''/g, "'");
		} catch {
			return trimmed.slice(1, -1);
		}
	}
	return trimmed;
}

function booleanValue(values, name) {
	const value = scalar(values, name);
	if (value === 'true') return true;
	if (value === 'false') return false;
	return undefined;
}

function collectionFor(filePath, values) {
	const relative = path.relative(CONTENT_ROOT, filePath).replaceAll('\\', '/');
	const parts = relative.split('/');
	if (parts[0] !== '_drafts') return parts[0];
	if (PUBLISHABLE_COLLECTIONS.has(parts[1])) return parts[1];

	if (values?.has('publishedAt')) return 'writing';
	if (values?.has('quote')) return 'quotes';
	if (values?.has('status') && values?.has('year')) return 'projects';
	if (values?.has('author') && values?.has('summary')) return 'books';
	if (values?.has('title') && values?.has('description')) return 'pages';
	return '_drafts';
}

function validateForPublication(contents, filePath, options) {
	const frontmatter = parseFrontmatter(contents);
	const { values } = frontmatter;
	const collection = collectionFor(filePath, values);
	const errors = [];

	if (!PUBLISHABLE_COLLECTIONS.has(collection)) {
		errors.push('Could not infer a destination collection for this draft.');
	}

	const required = {
		writing: ['title', 'description', 'publishedAt'],
		projects: ['title', 'summary', 'status', 'year'],
		books: ['title', 'author', 'summary'],
		quotes: ['quote', 'author'],
		galleries: ['title', 'description', 'date', 'coverImage', 'coverAlt'],
		pages: ['title', 'description'],
	}[collection] ?? ['title'];

	for (const field of required) {
		const value = scalar(values, field);
		if (!value || value === '[]' || /replace|todo|tbd/i.test(value)) {
			errors.push(`Frontmatter field "${field}" is missing or unfinished.`);
		}
	}

	const draft = booleanValue(values, 'draft');
	if (draft === undefined) errors.push('Frontmatter must contain draft: true or draft: false.');

	const placeholder = booleanValue(values, 'placeholder');
	if (placeholder === true && !options['allow-placeholder']) {
		errors.push(
			'This is placeholder content. Pass --allow-placeholder only for an intentional preview.',
		);
	}

	if (placeholder !== true) {
		const unfinished = contents.match(
			/\b(?:TODO|TBD|FIXME|REPLACE(?:\s+ME|\s+WITH)?)\b|example\.com/gi,
		);
		if (unfinished) {
			errors.push(`Unfinished marker found: ${[...new Set(unfinished)].join(', ')}`);
		}
	}

	return { ...frontmatter, collection, draft, errors };
}

function isWithin(parent, candidate) {
	const relative = path.relative(parent, candidate);
	return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative);
}

async function collectMarkdown(directory) {
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
			else if (/\.mdx?$/i.test(entry.name)) files.push(absolute);
		}
	}
	await walk(directory);
	return files.sort();
}

async function listDrafts() {
	const files = await collectMarkdown(CONTENT_ROOT);
	let count = 0;
	for (const file of files) {
		const firstSegment = path.relative(CONTENT_ROOT, file).split(path.sep)[0];
		if (firstSegment !== '_drafts' && !PUBLISHABLE_COLLECTIONS.has(firstSegment)) continue;
		const contents = await readFile(file, 'utf8');
		let frontmatter;
		try {
			frontmatter = parseFrontmatter(contents);
		} catch {
			continue;
		}
		if (/^draft:\s*true\s*$/m.test(frontmatter.yaml)) {
			console.log(path.relative(REPO_ROOT, file));
			count += 1;
		}
	}
	if (count === 0) console.log('No draft: true content found.');
}

function runCheck(script, mode) {
	const result = spawnSync(process.execPath, [path.join(REPO_ROOT, 'scripts', script), mode], {
		cwd: REPO_ROOT,
		encoding: 'utf8',
		stdio: 'pipe',
	});
	if (result.stdout) process.stdout.write(result.stdout);
	if (result.stderr) process.stderr.write(result.stderr);
	return result.status === 0;
}

async function replaceAtomically(filePath, updated) {
	const temporary = `${filePath}.tmp-${process.pid}-${Date.now()}`;
	await writeFile(temporary, updated, { encoding: 'utf8', flag: 'wx' });
	try {
		await rename(temporary, filePath);
	} catch (error) {
		if (!['EEXIST', 'EPERM'].includes(error.code)) throw error;
		await writeFile(filePath, updated, 'utf8');
		await unlink(temporary).catch(() => {});
	}
}

async function confirm(filePath) {
	if (!process.stdin.isTTY) {
		throw new Error('Interactive confirmation is unavailable; pass --yes to publish explicitly.');
	}
	const prompt = createInterface({ input: process.stdin, output: process.stdout });
	try {
		const answer = await prompt.question(
			`Publish ${path.relative(REPO_ROOT, filePath)} by setting draft: false? [y/N] `,
		);
		return /^y(?:es)?$/i.test(answer.trim());
	} finally {
		prompt.close();
	}
}

async function main() {
	const options = parseArgs(process.argv.slice(2));
	if (options.help) {
		usage();
		return;
	}
	if (options.list) {
		await listDrafts();
		return;
	}

	const supplied = options.positional[0];
	if (!supplied) throw new Error('Provide a Markdown file under src/content, or use --list.');

	const filePath = path.resolve(REPO_ROOT, supplied);
	if (!isWithin(CONTENT_ROOT, filePath) || !/\.mdx?$/i.test(filePath)) {
		throw new Error('The target must be a .md or .mdx file inside src/content.');
	}
	await access(filePath);

	const original = await readFile(filePath, 'utf8');
	const validation = validateForPublication(original, filePath, options);
	if (validation.errors.length > 0) {
		for (const error of validation.errors) console.error(`- ${error}`);
		throw new Error('Content is not ready to publish.');
	}

	const contentRelative = path.relative(CONTENT_ROOT, filePath).split(path.sep);
	const isPrivateDraft = contentRelative[0] === '_drafts';
	const destinationRelative =
		isPrivateDraft && contentRelative[1] === validation.collection
			? contentRelative.slice(2)
			: [path.basename(filePath)];
	const destination = isPrivateDraft
		? path.join(CONTENT_ROOT, validation.collection, ...destinationRelative)
		: filePath;

	if (validation.draft === false && !isPrivateDraft) {
		console.log(`${path.relative(REPO_ROOT, filePath)} is already published (draft: false).`);
		return;
	}
	if (options.check) {
		console.log(
			`${path.relative(REPO_ROOT, filePath)} is ready to publish to ${path.relative(REPO_ROOT, destination)}.`,
		);
		return;
	}

	if (!options.yes && !(await confirm(filePath))) {
		console.log('No changes made.');
		return;
	}

	const updatedYaml =
		validation.draft === true
			? validation.yaml.replace(/^draft:\s*true\s*$/m, 'draft: false')
			: validation.yaml;
	if (validation.draft === true && updatedYaml === validation.yaml) {
		throw new Error('Could not find an exact draft: true field.');
	}
	const updated = original.replace(validation.yaml, updatedYaml);

	if (isPrivateDraft) {
		await access(destination)
			.then(() => {
				throw new Error(`Destination already exists: ${path.relative(REPO_ROOT, destination)}`);
			})
			.catch((error) => {
				if (error.code !== 'ENOENT') throw error;
			});
		await mkdir(path.dirname(destination), { recursive: true });
		await writeFile(destination, updated, { encoding: 'utf8', flag: 'wx' });
	} else {
		await replaceAtomically(filePath, updated);
	}

	if (!options['skip-checks']) {
		const assetsOkay = runCheck('check-assets.mjs', 'source');
		const linksOkay = runCheck('check-links.mjs', 'source');
		if (!assetsOkay || !linksOkay) {
			if (isPrivateDraft) await unlink(destination).catch(() => {});
			else await replaceAtomically(filePath, original);
			throw new Error(
				`Checks failed; publication was rolled back${isPrivateDraft ? ' and the private draft was preserved' : ''}.`,
			);
		}
	}

	if (isPrivateDraft) await unlink(filePath);

	console.log(`Published locally: ${path.relative(REPO_ROOT, destination)}`);
	console.log('Review the diff. Nothing was committed or pushed.');
}

main().catch((error) => {
	console.error(`publish-content: ${error.message}`);
	process.exitCode = 1;
});
