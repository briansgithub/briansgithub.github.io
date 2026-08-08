#!/usr/bin/env node

import { mkdir, readFile, rename, stat, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = fileURLToPath(new URL('../', import.meta.url));
const IMAGE_ROOT = path.join(REPO_ROOT, 'src', 'assets', 'images');
const MAX_LONG_EDGE = 2400;
const MIN_LONG_EDGE = 640;
const MAX_OUTPUT_BYTES = 2 * 1024 * 1024;
const MAX_INPUT_BYTES = 100 * 1024 * 1024;
const WEBP_QUALITY = 82;

function usage() {
	console.log(`Import one raster image as a safe web master.

Usage:
  node scripts/import-media.mjs <source-file> --alt <text> [options]

Options:
  --name <slug>          Output filename without .webp
  --subdir <path>        Safe subdirectory below src/assets/images
  --content <file>       Print a path relative to this Markdown/MDX file
  --alt <text>           Required descriptive alternative text
  --help                 Show this help

Output is WebP quality 82, at most 2400 px on the long edge and 2 MiB.
Metadata, including EXIF/GPS, is removed. The source is never changed or deleted.`);
}

function parseArgs(argv) {
	const options = { positional: [] };
	for (let index = 0; index < argv.length; index += 1) {
		const value = argv[index];
		if (!value.startsWith('--')) {
			options.positional.push(value);
			continue;
		}

		const [name, inlineValue] = value.slice(2).split('=', 2);
		if (name === 'help') {
			options.help = true;
			continue;
		}
		if (!['name', 'subdir', 'content', 'alt'].includes(name)) {
			throw new Error(`Unknown option: --${name}`);
		}
		const optionValue = inlineValue ?? argv[index + 1];
		if (inlineValue === undefined) index += 1;
		if (optionValue === undefined || optionValue.startsWith('--')) {
			throw new Error(`--${name} requires a value.`);
		}
		options[name] = optionValue;
	}
	options.source = options.positional[0];
	return options;
}

function slugify(value) {
	return value
		.normalize('NFKD')
		.replace(/[\u0300-\u036f]/g, '')
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, '-')
		.replace(/^-+|-+$/g, '')
		.replace(/-{2,}/g, '-');
}

function isWithin(parent, candidate) {
	const relative = path.relative(parent, candidate);
	return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
}

function safeSubdirectory(value = '') {
	if (!value) return '';
	const segments = value.replaceAll('\\', '/').split('/').filter(Boolean);
	if (segments.some((segment) => slugify(segment) !== segment)) {
		throw new Error('--subdir must contain lowercase kebab-case path segments only.');
	}
	return path.join(...segments);
}

function meaningfulAlt(value, source) {
	const alt = String(value ?? '').trim();
	const sourceName = path.parse(source || '').name.toLowerCase();
	if (alt.length < 3 || /^(image|photo|picture|thumbnail)$/i.test(alt)) {
		throw new Error('--alt must contain a meaningful description.');
	}
	if (alt.toLowerCase() === sourceName) {
		throw new Error('--alt should describe the image, not repeat its filename.');
	}
	return alt;
}

async function loadSharp() {
	try {
		const module = await import('sharp');
		return module.default;
	} catch {
		throw new Error('Sharp is required. Add it to the project with: npm install sharp');
	}
}

async function encodeAtLimit(sharp, sourcePath, startingEdge) {
	let longEdge = Math.min(MAX_LONG_EDGE, Math.max(MIN_LONG_EDGE, startingEdge));
	let buffer;
	let info;

	while (longEdge >= MIN_LONG_EDGE) {
		({ data: buffer, info } = await sharp(sourcePath, {
			failOn: 'warning',
			limitInputPixels: 100_000_000,
		})
			.rotate()
			.resize({
				width: longEdge,
				height: longEdge,
				fit: 'inside',
				withoutEnlargement: true,
			})
			.webp({ quality: WEBP_QUALITY, effort: 5, smartSubsample: true })
			.toBuffer({ resolveWithObject: true }));

		if (buffer.byteLength <= MAX_OUTPUT_BYTES) return { buffer, info };
		longEdge = Math.floor(longEdge * 0.85);
	}

	throw new Error('The optimized image still exceeds 2 MiB at the minimum allowed dimensions.');
}

async function main() {
	const options = parseArgs(process.argv.slice(2));
	if (options.help) {
		usage();
		return;
	}
	if (!options.source) throw new Error('Provide a source image path.');

	const sourcePath = path.resolve(options.source);
	const sourceStat = await stat(sourcePath);
	if (!sourceStat.isFile()) throw new Error('The source path must be a file.');
	if (sourceStat.size > MAX_INPUT_BYTES)
		throw new Error('Source images larger than 100 MiB are refused.');
	if (isWithin(IMAGE_ROOT, sourcePath)) {
		throw new Error(
			'Choose a source outside src/assets/images to avoid overwriting managed output.',
		);
	}

	const alt = meaningfulAlt(options.alt, sourcePath);
	const requestedName = options.name?.replace(/\.webp$/i, '') || path.parse(sourcePath).name;
	const outputName = slugify(requestedName);
	if (!outputName) throw new Error('Could not derive a safe output name; provide --name.');
	if (options.name && outputName !== requestedName) {
		throw new Error('--name must be lowercase kebab-case.');
	}

	const outputDirectory = path.resolve(IMAGE_ROOT, safeSubdirectory(options.subdir));
	if (!isWithin(IMAGE_ROOT, outputDirectory))
		throw new Error('Output path escaped the managed image directory.');
	const destination = path.join(outputDirectory, `${outputName}.webp`);

	let markdownTarget;
	if (options.content) {
		const contentPath = path.resolve(REPO_ROOT, options.content);
		if (
			!isWithin(path.join(REPO_ROOT, 'src', 'content'), contentPath) ||
			!/\.mdx?$/i.test(contentPath)
		) {
			throw new Error('--content must point to a .md or .mdx file inside src/content.');
		}
		markdownTarget = path.relative(path.dirname(contentPath), destination).replaceAll('\\', '/');
		if (!markdownTarget.startsWith('.')) markdownTarget = `./${markdownTarget}`;
	} else {
		markdownTarget = path.relative(REPO_ROOT, destination).replaceAll('\\', '/');
	}

	try {
		await readFile(destination);
		throw new Error(`Output already exists: ${path.relative(REPO_ROOT, destination)}`);
	} catch (error) {
		if (error.code !== 'ENOENT') throw error;
	}

	const sharp = await loadSharp();
	const metadata = await sharp(sourcePath, {
		failOn: 'warning',
		limitInputPixels: 100_000_000,
	}).metadata();
	const allowedFormats = new Set(['jpeg', 'png', 'webp', 'avif', 'tiff', 'heif', 'gif']);
	if (!allowedFormats.has(metadata.format)) {
		throw new Error(`Unsupported raster format: ${metadata.format || 'unknown'}.`);
	}
	if ((metadata.pages || 1) > 1) {
		throw new Error('Animated or multi-page images require deliberate manual handling.');
	}

	const sourceLongEdge = Math.max(metadata.width || 0, metadata.height || 0, MIN_LONG_EDGE);
	const { buffer, info } = await encodeAtLimit(sharp, sourcePath, sourceLongEdge);

	await mkdir(outputDirectory, { recursive: true });
	const temporary = `${destination}.tmp-${process.pid}-${Date.now()}`;
	await writeFile(temporary, buffer, { flag: 'wx' });
	try {
		await rename(temporary, destination);
	} catch (error) {
		await unlink(temporary).catch(() => {});
		throw error;
	}

	console.log(`Created: ${path.relative(REPO_ROOT, destination)}`);
	console.log(`Dimensions: ${info.width} x ${info.height}`);
	console.log(`Size: ${(buffer.byteLength / 1024).toFixed(1)} KiB`);
	if (!options.content) {
		console.log('Pass --content <file.md> next time for an immediately pasteable relative path.');
	}
	console.log('Markdown snippet:');
	console.log(`![${alt.replaceAll(']', '\\]')}](${markdownTarget})`);
	console.log('The source image was not changed or deleted. Nothing was committed or pushed.');
}

main().catch((error) => {
	console.error(`import-media: ${error.message}`);
	process.exitCode = 1;
});
