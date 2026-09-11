import { site } from '../data/site';
import { isContentVisible, type VisibilityData } from './visibility';

export function contentSlug(id: string) {
	return id.replace(/\\/g, '/').replace(/\/index$/, '');
}

export function formatDate(date: Date) {
	return new Intl.DateTimeFormat('en-US', {
		year: 'numeric',
		month: 'long',
		day: 'numeric',
		timeZone: 'UTC',
	}).format(date);
}

export function isVisible(data: VisibilityData, options: { preview?: boolean } = {}) {
	const preview = options.preview ?? site.preview;
	return isContentVisible(data, preview);
}

export function isGithubUrl(href: string) {
	try {
		const host = new URL(href).hostname.toLowerCase();
		return host === 'github.com' || host === 'www.github.com';
	} catch {
		return false;
	}
}

export function githubHref(links?: Record<string, string>) {
	if (!links) return undefined;
	return Object.values(links).find(isGithubUrl);
}

export function projectPageLinks(links?: Record<string, string>) {
	if (!links) return [];
	return Object.entries(links)
		.map(([label, href]) => ({
			label: isGithubUrl(href) ? 'GitHub' : label,
			href,
		}))
		.sort((a, b) => Number(isGithubUrl(b.href)) - Number(isGithubUrl(a.href)));
}
