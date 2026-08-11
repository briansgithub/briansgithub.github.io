import { spawnSync } from 'node:child_process';
import { existsSync, lstatSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, extname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIRECTORY = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(SCRIPT_DIRECTORY, '..');
const BUDGET_PATH = join(PROJECT_ROOT, 'config', 'size-budgets.json');
const GIT_MAX_BUFFER = 256 * 1024 * 1024;
const VALID_MODES = new Set(['source', 'staged', 'outgoing', 'dist']);

function toPosixPath(value) {
	return value.replaceAll('\\', '/');
}

function projectPath(absolutePath) {
	return toPosixPath(relative(PROJECT_ROOT, absolutePath));
}

function formatBytes(bytes) {
	if (bytes < 1024) return `${bytes} B`;

	const units = ['KiB', 'MiB', 'GiB'];
	let value = bytes;
	let unit = 'B';
	for (const candidate of units) {
		value /= 1024;
		unit = candidate;
		if (value < 1024) break;
	}

	const digits = value >= 100 ? 0 : value >= 10 ? 1 : 2;
	return `${value.toFixed(digits)} ${unit}`;
}

function loadBudgets() {
	let parsed;
	try {
		parsed = JSON.parse(readFileSync(BUDGET_PATH, 'utf8'));
	} catch (error) {
		throw new Error(`Could not read ${projectPath(BUDGET_PATH)}: ${error.message}`);
	}

	const requiredNumbers = [
		['source.warningTotalBytes', parsed.source?.warningTotalBytes],
		['source.maximumTotalBytes', parsed.source?.maximumTotalBytes],
		['source.maximumFileBytes', parsed.source?.maximumFileBytes],
		['source.warningImageBytes', parsed.source?.warningImageBytes],
		['source.maximumImageBytes', parsed.source?.maximumImageBytes],
		['source.warningDocumentBytes', parsed.source?.warningDocumentBytes],
		['source.maximumDocumentBytes', parsed.source?.maximumDocumentBytes],
		['dist.warningTotalBytes', parsed.dist?.warningTotalBytes],
		['dist.maximumTotalBytes', parsed.dist?.maximumTotalBytes],
		['dist.maximumFileBytes', parsed.dist?.maximumFileBytes],
		['dist.warningImageBytes', parsed.dist?.warningImageBytes],
		['dist.maximumImageBytes', parsed.dist?.maximumImageBytes],
		['dist.warningHtmlBytes', parsed.dist?.warningHtmlBytes],
		['dist.maximumHtmlBytes', parsed.dist?.maximumHtmlBytes],
		['dist.warningScriptStyleBytes', parsed.dist?.warningScriptStyleBytes],
		['dist.maximumScriptStyleBytes', parsed.dist?.maximumScriptStyleBytes],
		['dist.maximumDocumentBytes', parsed.dist?.maximumDocumentBytes],
	];

	for (const [name, value] of requiredNumbers) {
		if (!Number.isSafeInteger(value) || value <= 0) {
			throw new Error(`${name} must be a positive integer number of bytes`);
		}
	}

	if (!parsed.extensions?.forbidden || !parsed.inlineDataUriPattern) {
		throw new Error('The budget file is missing extension or inline-data rules');
	}

	return parsed;
}

function runGit(args, options = {}) {
	const result = spawnSync('git', args, {
		cwd: PROJECT_ROOT,
		encoding: options.encoding ?? 'utf8',
		input: options.input,
		maxBuffer: GIT_MAX_BUFFER,
		windowsHide: true,
	});

	return {
		error: result.error,
		ok: !result.error && result.status === 0,
		status: result.status,
		stderr:
			typeof result.stderr === 'string'
				? result.stderr.trim()
				: (result.stderr?.toString('utf8').trim() ?? ''),
		stdout: result.stdout ?? '',
	};
}

function requireGit(args, description, options = {}) {
	const result = runGit(args, options);
	if (!result.ok) {
		const detail = result.error?.message || result.stderr || `exit ${result.status}`;
		throw new Error(`${description} failed: ${detail}`);
	}
	return result.stdout;
}

function isGitRepository() {
	const result = runGit(['rev-parse', '--is-inside-work-tree']);
	return result.ok && result.stdout.trim() === 'true';
}

function splitNulls(value) {
	return value.split('\0').filter(Boolean);
}

function filesystemItem(absolutePath, displayPath = projectPath(absolutePath)) {
	const stats = lstatSync(absolutePath);
	return {
		isSymlink: stats.isSymbolicLink(),
		path: displayPath,
		paths: [displayPath],
		read: stats.isSymbolicLink() ? undefined : () => readFileSync(absolutePath),
		size: stats.size,
	};
}

function collectTrackedSource() {
	const output = requireGit(
		['ls-files', '--cached', '--others', '--exclude-standard', '-z'],
		'Listing tracked and untracked source files',
	);
	const items = [];

	for (const name of splitNulls(output)) {
		const absolutePath = join(PROJECT_ROOT, name);
		if (!existsSync(absolutePath)) continue;

		const stats = lstatSync(absolutePath);
		if (!stats.isFile() && !stats.isSymbolicLink()) continue;
		items.push(filesystemItem(absolutePath, toPosixPath(name)));
	}

	return {
		items,
		notes: ['Scanned tracked and non-ignored untracked files from the working tree.'],
	};
}

function isIgnoredDirectory(relativePath, ignoredDirectories) {
	const normalized = toPosixPath(relativePath).replace(/^\.\//, '');
	return ignoredDirectories.some(
		(ignored) => normalized === ignored || normalized.startsWith(`${ignored}/`),
	);
}

function collectFilesystemSource(budgets) {
	const items = [];
	const ignoredDirectories = budgets.sourceIgnoreDirectories.map((entry) =>
		toPosixPath(entry).replace(/^\.\//, '').replace(/\/$/, ''),
	);

	function walk(directory) {
		for (const entry of readdirSync(directory, { withFileTypes: true })) {
			const absolutePath = join(directory, entry.name);
			const relativePath = projectPath(absolutePath);

			if (entry.isDirectory()) {
				if (!isIgnoredDirectory(relativePath, ignoredDirectories)) walk(absolutePath);
				continue;
			}

			if (entry.isFile() || entry.isSymbolicLink()) {
				items.push(filesystemItem(absolutePath, relativePath));
			}
		}
	}

	walk(PROJECT_ROOT);
	return {
		items,
		notes: [
			'Git repository not found; scanned the project filesystem using the configured directory exclusions.',
		],
	};
}

function collectSource(budgets) {
	return isGitRepository() ? collectTrackedSource() : collectFilesystemSource(budgets);
}

function objectMetadata(objectIds) {
	const uniqueIds = [...new Set(objectIds)];
	if (uniqueIds.length === 0) return new Map();

	const output = requireGit(
		['cat-file', '--batch-check=%(objectname) %(objecttype) %(objectsize)'],
		'Reading Git object metadata',
		{ input: `${uniqueIds.join('\n')}\n` },
	);
	const metadata = new Map();

	for (const line of output.trim().split(/\r?\n/)) {
		if (!line) continue;
		const [oid, type, rawSize] = line.split(' ');
		const size = Number(rawSize);
		if (oid && type && Number.isSafeInteger(size)) {
			metadata.set(oid, { size, type });
		}
	}

	return metadata;
}

function readGitBlob(oid) {
	const output = requireGit(['cat-file', 'blob', oid], `Reading Git blob ${oid}`, {
		encoding: null,
	});
	return Buffer.isBuffer(output) ? output : Buffer.from(output);
}

function collectStaged() {
	if (!isGitRepository()) {
		throw new Error('The staged mode requires an initialized Git repository');
	}

	const changedNames = new Set(
		splitNulls(
			requireGit(
				['diff', '--cached', '--name-only', '--diff-filter=ACMRT', '-z'],
				'Listing staged paths',
			),
		),
	);
	if (changedNames.size === 0) {
		return { items: [], notes: ['No added or modified files are staged.'] };
	}

	const indexEntries = splitNulls(
		requireGit(['ls-files', '--stage', '-z'], 'Reading the Git index'),
	);
	const selected = [];

	for (const entry of indexEntries) {
		const tab = entry.indexOf('\t');
		if (tab < 0) continue;
		const header = entry.slice(0, tab).split(' ');
		const path = entry.slice(tab + 1);
		const [mode, oid, stage] = header;
		if (stage === '0' && changedNames.has(path)) {
			selected.push({ mode, oid, path: toPosixPath(path) });
		}
	}

	const metadata = objectMetadata(selected.map((entry) => entry.oid));
	const items = [];
	for (const entry of selected) {
		const details = metadata.get(entry.oid);
		if (!details || details.type !== 'blob') continue;
		items.push({
			isSymlink: entry.mode === '120000',
			oid: entry.oid,
			path: entry.path,
			paths: [entry.path],
			read: entry.mode === '120000' ? undefined : () => readGitBlob(entry.oid),
			size: details.size,
		});
	}

	return {
		items,
		notes: ['Scanned blob contents from the Git index, not working-tree copies.'],
	};
}

function isZeroOid(oid) {
	return /^0+$/.test(oid);
}

function readPushUpdates() {
	if (process.stdin.isTTY) return [];

	let input = '';
	try {
		input = readFileSync(0, 'utf8');
	} catch {
		return [];
	}

	const updates = [];
	for (const line of input.trim().split(/\r?\n/)) {
		if (!line) continue;
		const [localRef, localOid, remoteRef, remoteOid] = line.trim().split(/\s+/);
		if (localRef && localOid && remoteRef && remoteOid) {
			updates.push({ localOid, localRef, remoteOid, remoteRef });
		}
	}
	return updates;
}

function revListObjects(revisions) {
	return requireGit(
		['-c', 'core.quotePath=false', 'rev-list', '--objects', ...revisions],
		'Listing outgoing Git objects',
	);
}

function fallbackOutgoingRevisions() {
	const head = runGit(['rev-parse', '--verify', 'HEAD']);
	if (!head.ok) return null;

	const upstream = runGit(['rev-parse', '--verify', '@{upstream}']);
	if (upstream.ok) {
		return {
			note: 'No pre-push input was available; compared HEAD with its upstream.',
			revisions: [`${upstream.stdout.trim()}..${head.stdout.trim()}`],
		};
	}

	return {
		note: 'No pre-push input or upstream was available; conservatively scanned HEAD objects not reachable from any remote-tracking ref.',
		revisions: [head.stdout.trim(), '--not', '--remotes'],
	};
}

function parseRevListOutput(output, objectPaths) {
	for (const line of output.split(/\r?\n/)) {
		if (!line) continue;
		const separator = line.indexOf(' ');
		const oid = separator < 0 ? line : line.slice(0, separator);
		let path = separator < 0 ? `[Git object ${oid}]` : line.slice(separator + 1);
		if (path.startsWith('"') && path.endsWith('"')) {
			path = path.slice(1, -1);
		}
		const paths = objectPaths.get(oid) ?? new Set();
		paths.add(toPosixPath(path));
		objectPaths.set(oid, paths);
	}
}

function collectOutgoingFromObjects(updates) {
	const remoteName = process.argv[3] && !process.argv[3].startsWith('-') ? process.argv[3] : null;
	const objectPaths = new Map();
	const notes = [];

	if (updates.length > 0) {
		for (const update of updates) {
			if (isZeroOid(update.localOid)) continue;

			const revisions = isZeroOid(update.remoteOid)
				? [update.localOid, '--not', remoteName ? `--remotes=${remoteName}` : '--remotes']
				: [`${update.remoteOid}..${update.localOid}`];
			parseRevListOutput(revListObjects(revisions), objectPaths);
		}
		notes.push("Scanned blobs reachable from the refs supplied by Git's pre-push hook.");
	} else {
		const fallback = fallbackOutgoingRevisions();
		if (!fallback) {
			return { items: [], notes: ['No outgoing commits exist yet.'] };
		}
		parseRevListOutput(revListObjects(fallback.revisions), objectPaths);
		notes.push(fallback.note);
	}

	const metadata = objectMetadata([...objectPaths.keys()]);
	const items = [];
	for (const [oid, paths] of objectPaths) {
		const details = metadata.get(oid);
		if (!details || details.type !== 'blob') continue;

		const sortedPaths = [...paths].sort();
		items.push({
			isSymlink: false,
			oid,
			path: sortedPaths[0],
			paths: sortedPaths,
			read: () => readGitBlob(oid),
			size: details.size,
		});
	}

	return { items, notes };
}

function collectOutgoing(budgets) {
	if (!isGitRepository()) {
		throw new Error('The outgoing mode requires an initialized Git repository');
	}

	const updates = readPushUpdates();
	try {
		return collectOutgoingFromObjects(updates);
	} catch (error) {
		const fallback = collectSource(budgets);
		fallback.notes.unshift(
			`Could not enumerate outgoing Git objects (${error.message}); fell back to a source scan.`,
		);
		return fallback;
	}
}

function collectDist(budgets) {
	const distRoot = resolve(PROJECT_ROOT, budgets.distDirectory);
	if (!existsSync(distRoot)) {
		throw new Error(
			`${toPosixPath(budgets.distDirectory)}/ does not exist; build the site before running dist mode`,
		);
	}

	const items = [];
	function walk(directory) {
		for (const entry of readdirSync(directory, { withFileTypes: true })) {
			const absolutePath = join(directory, entry.name);
			if (entry.isDirectory()) {
				walk(absolutePath);
			} else if (entry.isFile() || entry.isSymbolicLink()) {
				items.push(filesystemItem(absolutePath));
			}
		}
	}

	walk(distRoot);
	return {
		items,
		notes: ['Scanned the generated site recursively without following symbolic links.'],
	};
}

function extensionSet(entries) {
	return new Set(entries.map((entry) => entry.toLowerCase()));
}

function createRules(budgets) {
	const forbidden = new Map();
	for (const [label, extensions] of Object.entries(budgets.extensions.forbidden)) {
		for (const extension of extensions) forbidden.set(extension.toLowerCase(), label);
	}

	return {
		documents: extensionSet(budgets.extensions.documents),
		forbidden,
		html: extensionSet(budgets.extensions.html),
		images: extensionSet(budgets.extensions.images),
		inlineData: new RegExp(budgets.inlineDataUriPattern, 'i'),
		scriptStyleExceptions: (budgets.dist.scriptStyleExceptions ?? []).map((entry) => ({
			...entry,
			regex: new RegExp(entry.pattern),
		})),
		scriptsAndStyles: extensionSet(budgets.extensions.scriptsAndStyles),
		textInspection: extensionSet(budgets.textInspectionExtensions),
	};
}

function displayPaths(item) {
	if (item.paths.length <= 2) return item.paths.join(', ');
	return `${item.paths.slice(0, 2).join(', ')} (+${item.paths.length - 2} more paths)`;
}

function strictestSizeRule(item, mode, budgets, rules) {
	const limits = mode === 'dist' ? budgets.dist : budgets.source;

	if (mode === 'dist') {
		const exception = rules.scriptStyleExceptions.find((entry) =>
			item.paths.some((path) => entry.regex.test(path)),
		);
		if (exception) {
			return {
				label: exception.reason,
				maximum: exception.maximumBytes,
				warning: exception.warningBytes,
			};
		}
	}

	const candidates = [{ label: 'ordinary file', maximum: limits.maximumFileBytes }];
	const extensions = item.paths.map((path) => extname(path).toLowerCase());

	if (extensions.some((extension) => rules.images.has(extension))) {
		candidates.push({
			label: mode === 'dist' ? 'generated image' : 'source image',
			maximum: limits.maximumImageBytes,
			warning: limits.warningImageBytes,
		});
	}
	if (extensions.some((extension) => rules.documents.has(extension))) {
		candidates.push({
			label: 'document',
			maximum: limits.maximumDocumentBytes,
			warning: mode === 'source' ? limits.warningDocumentBytes : undefined,
		});
	}
	if (mode === 'dist' && extensions.some((extension) => rules.html.has(extension))) {
		candidates.push({
			label: 'generated HTML',
			maximum: limits.maximumHtmlBytes,
			warning: limits.warningHtmlBytes,
		});
	}
	if (mode === 'dist' && extensions.some((extension) => rules.scriptsAndStyles.has(extension))) {
		candidates.push({
			label: 'generated script or stylesheet',
			maximum: limits.maximumScriptStyleBytes,
			warning: limits.warningScriptStyleBytes,
		});
	}

	return candidates.sort((left, right) => left.maximum - right.maximum)[0];
}

function inspect(items, mode, budgets) {
	const rules = createRules(budgets);
	const failures = [];
	const warnings = [];
	let totalBytes = 0;

	for (const item of items) {
		totalBytes += item.size;
		const shownPath = displayPaths(item);

		if (mode === 'dist' && item.isSymlink) {
			failures.push(`${shownPath}: symbolic links are not allowed in the generated site`);
		}

		for (const path of item.paths) {
			const extension = extname(path).toLowerCase();
			const forbiddenLabel = rules.forbidden.get(extension);
			if (forbiddenLabel) {
				failures.push(
					`${path}: forbidden ${forbiddenLabel} extension (${extension}); keep it outside the website repository`,
				);
			}
		}

		const sizeRule = strictestSizeRule(item, mode, budgets, rules);
		if (item.size > sizeRule.maximum) {
			failures.push(
				`${shownPath}: ${formatBytes(item.size)} exceeds the ${formatBytes(sizeRule.maximum)} ${sizeRule.label} limit`,
			);
		} else if (sizeRule.warning && item.size > sizeRule.warning) {
			warnings.push(
				`${shownPath}: ${formatBytes(item.size)} exceeds the ${formatBytes(sizeRule.warning)} ${sizeRule.label} warning threshold`,
			);
		}

		const inspectText = item.paths.some((path) =>
			rules.textInspection.has(extname(path).toLowerCase()),
		);
		if (inspectText && item.read) {
			try {
				const content = item.read().toString('utf8');
				if (rules.inlineData.test(content)) {
					failures.push(
						`${shownPath}: contains an inline image/audio/video data URI; store an optimized asset as a separate file`,
					);
				}
			} catch (error) {
				failures.push(`${shownPath}: could not inspect file content (${error.message})`);
			}
		}
	}

	const limits = mode === 'dist' ? budgets.dist : budgets.source;
	if (totalBytes > limits.maximumTotalBytes) {
		failures.push(
			`total ${mode} size ${formatBytes(totalBytes)} exceeds the ${formatBytes(limits.maximumTotalBytes)} limit`,
		);
	} else if (totalBytes > limits.warningTotalBytes) {
		warnings.push(
			`total ${mode} size ${formatBytes(totalBytes)} exceeds the ${formatBytes(limits.warningTotalBytes)} warning threshold`,
		);
	}

	return { failures, totalBytes, warnings };
}

function printResult(mode, collection, result) {
	console.log(
		`[asset-guard] ${mode}: checked ${collection.items.length} file${collection.items.length === 1 ? '' : 's'} (${formatBytes(result.totalBytes)} total).`,
	);
	for (const note of collection.notes) console.log(`[asset-guard] note: ${note}`);

	if (result.warnings.length > 0) {
		console.warn(`[asset-guard] ${result.warnings.length} warning(s):`);
		for (const warning of result.warnings) console.warn(`  - ${warning}`);
	}

	if (result.failures.length > 0) {
		console.error(`[asset-guard] FAILED with ${result.failures.length} violation(s):`);
		for (const failure of result.failures) console.error(`  - ${failure}`);
		process.exitCode = 1;
	} else {
		console.log('[asset-guard] PASS: all asset checks are within budget.');
	}
}

function usage() {
	console.error('Usage: node scripts/check-assets.mjs <source|staged|outgoing|dist> [remote-name]');
}

function main() {
	const mode = (process.argv[2] ?? 'source').toLowerCase();
	if (['--help', '-h'].includes(mode)) {
		usage();
		return;
	}
	if (!VALID_MODES.has(mode)) {
		usage();
		process.exitCode = 2;
		return;
	}

	const budgets = loadBudgets();
	let collection;
	if (mode === 'source') collection = collectSource(budgets);
	if (mode === 'staged') collection = collectStaged();
	if (mode === 'outgoing') collection = collectOutgoing(budgets);
	if (mode === 'dist') collection = collectDist(budgets);

	const result = inspect(collection.items, mode, budgets);
	printResult(mode, collection, result);
}

try {
	main();
} catch (error) {
	console.error(`[asset-guard] ERROR: ${error.message}`);
	process.exitCode = 2;
}
