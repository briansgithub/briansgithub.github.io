#!/usr/bin/env node

import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { createInterface } from 'node:readline/promises';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = fileURLToPath(new URL('../', import.meta.url));
const CONTENT_ROOT = path.join(REPO_ROOT, 'src', 'content');

const TYPE_ALIASES = new Map([
	['writing', 'writing'],
	['post', 'writing'],
	['article', 'writing'],
	['project', 'project'],
	['projects', 'project'],
	['book', 'book'],
	['books', 'book'],
	['book-note', 'book'],
	['quotation', 'quotation'],
	['quote', 'quotation'],
	['page', 'page'],
	['fixed-page', 'page'],
]);

function usage() {
	console.log(`Create a safe draft in src/content.

Usage:
  node scripts/new-content.mjs <type> <slug> [options]

Types:
  writing | project | book | quotation | page

Options:
  --title <text>         Display title (defaults from the slug)
  --description <text>   Short description
  --date <YYYY-MM-DD>    Publication date for writing (defaults to today)
  --help                 Show this help

Missing values are prompted for when run in an interactive terminal.
The command never overwrites an existing file and never runs Git.`);
}

function parseArgs(argv) {
	const options = {};
	const positional = [];

	for (let index = 0; index < argv.length; index += 1) {
		const value = argv[index];
		if (!value.startsWith('--')) {
			positional.push(value);
			continue;
		}

		const [rawName, inlineValue] = value.slice(2).split('=', 2);
		if (rawName === 'help') {
			options.help = true;
			continue;
		}

		const nextValue = inlineValue ?? argv[index + 1];
		if (inlineValue === undefined) index += 1;
		if (!nextValue || nextValue.startsWith('--')) {
			throw new Error(`--${rawName} requires a value.`);
		}
		options[rawName] = nextValue;
	}

	return {
		type: positional[0] ?? options.type,
		slug: positional[1] ?? options.slug,
		...options,
	};
}

function todayLocal() {
	const now = new Date();
	const year = now.getFullYear();
	const month = String(now.getMonth() + 1).padStart(2, '0');
	const day = String(now.getDate()).padStart(2, '0');
	return `${year}-${month}-${day}`;
}

function isIsoDate(value) {
	if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
	const parsed = new Date(`${value}T00:00:00Z`);
	return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().startsWith(value);
}

function slugify(value) {
	return value
		.normalize('NFKD')
		.replace(/[\u0300-\u036f]/g, '')
		.toLowerCase()
		.replace(/&/g, ' and ')
		.replace(/[^a-z0-9]+/g, '-')
		.replace(/^-+|-+$/g, '')
		.replace(/-{2,}/g, '-');
}

function titleFromSlug(slug) {
	return slug
		.split('-')
		.filter(Boolean)
		.map((word) => word.charAt(0).toUpperCase() + word.slice(1))
		.join(' ');
}

function yamlString(value) {
	return JSON.stringify(String(value));
}

function buildDraft({ type, slug, title, description, date }) {
	const common = {
		title,
		description: description || 'Replace this description before publishing.',
	};

	if (type === 'writing') {
		return {
			relativePath: path.join('_drafts', 'writing', `${slug}.md`),
			contents: `---
title: ${yamlString(common.title)}
description: ${yamlString(common.description)}
publishedAt: ${date}
tags: []
featured: false
draft: true
placeholder: false
---

## Opening

Start writing here.
`,
		};
	}

	if (type === 'project') {
		return {
			relativePath: path.join('_drafts', 'projects', `${slug}.md`),
			contents: `---
title: ${yamlString(common.title)}
summary: ${yamlString(common.description)}
status: active
year: ${date.slice(0, 4)}
technologies: []
featured: false
draft: true
placeholder: false
---

## The problem

What are you trying to understand or build?

## The approach

Document the design and the important tradeoffs.

## Results

Record evidence, validation, and what you would change next.
`,
		};
	}

	if (type === 'book') {
		return {
			relativePath: path.join('_drafts', 'books', `${slug}.md`),
			contents: `---
title: ${yamlString(common.title)}
author: ${yamlString('Replace with the author')}
summary: ${yamlString(common.description)}
tags: []
draft: true
placeholder: false
---

## Summary

Write the summary in your own words.

## Ideas worth keeping

- Add a useful idea.

## Questions and reactions

What changed or became clearer after reading?
`,
		};
	}

	if (type === 'quotation') {
		return {
			relativePath: path.join('_drafts', 'quotes', `${slug}.md`),
			contents: `---
quote: ${yamlString('Replace with a verified quotation')}
author: ${yamlString('Replace with the attribution')}
source: ${yamlString('Verify and cite the source')}
draft: true
placeholder: false
---
`,
		};
	}

	return {
		relativePath: path.join('_drafts', 'pages', `${slug}.md`),
		contents: `---
title: ${yamlString(common.title)}
description: ${yamlString(common.description)}
draft: true
placeholder: false
---

## ${common.title}

Start writing here.
`,
	};
}

async function promptForMissing(options) {
	if (!process.stdin.isTTY) return options;
	const prompt = createInterface({ input: process.stdin, output: process.stdout });
	try {
		const type =
			options.type || (await prompt.question('Type (writing/project/book/quotation/page): '));
		const title = options.title || (await prompt.question('Title: '));
		const slug =
			options.slug || (await prompt.question(`Slug [${slugify(title)}]: `)) || slugify(title);
		const description =
			options.description || (await prompt.question('Short description (optional): '));
		return { ...options, type, title, slug, description };
	} finally {
		prompt.close();
	}
}

async function main() {
	let options = parseArgs(process.argv.slice(2));
	if (options.help) {
		usage();
		return;
	}

	options = await promptForMissing(options);

	const type = TYPE_ALIASES.get(String(options.type || '').toLowerCase());
	if (!type) {
		throw new Error('Choose one of: writing, project, book, quotation, or page.');
	}

	const title = String(options.title || titleFromSlug(options.slug || '')).trim();
	const slug = slugify(options.slug || title);
	if (!title) throw new Error('A title is required.');
	if (!slug || (slug !== options.slug && options.slug)) {
		const supplied = options.slug ? ` Supplied slug: ${options.slug}` : '';
		throw new Error(`Use a lowercase kebab-case slug such as "${slug}".${supplied}`);
	}

	const date = options.date || todayLocal();
	if (!isIsoDate(date)) throw new Error('--date must use YYYY-MM-DD.');

	const draft = buildDraft({
		type,
		slug,
		title,
		description: String(options.description || '').trim(),
		date,
	});
	const destination = path.join(CONTENT_ROOT, draft.relativePath);

	await mkdir(path.dirname(destination), { recursive: true });
	await writeFile(destination, draft.contents, { encoding: 'utf8', flag: 'wx' });

	console.log(`Created draft: ${path.relative(REPO_ROOT, destination)}`);
	console.log('The _drafts directory is Git-ignored; back it up separately.');
	console.log('Nothing was committed or pushed.');
}

main().catch((error) => {
	console.error(`new-content: ${error.message}`);
	process.exitCode = 1;
});
