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

export type ProjectAppType =
	'pwa' | 'web-app' | 'chrome-extension' | 'android' | 'ios' | 'desktop' | 'cli';

export interface ProjectApp {
	type: ProjectAppType;
	url: string;
	note?: string;
}

export function appTypeLabel(type: ProjectAppType) {
	const labels: Record<ProjectAppType, string> = {
		pwa: 'Progressive Web App',
		'web-app': 'Web App',
		'chrome-extension': 'Chrome Extension',
		android: 'Android App',
		ios: 'iOS App',
		desktop: 'Desktop App',
		cli: 'Command-Line Tool',
	};
	return labels[type];
}

export function appActionLabel(type: ProjectAppType) {
	if (type === 'chrome-extension') return 'Install extension';
	if (type === 'android' || type === 'ios' || type === 'desktop') return 'Get app';
	if (type === 'cli') return 'Get tool';
	return 'Open app';
}

export function projectPageLinks(links?: Record<string, string>, app?: ProjectApp) {
	const projectLinks = Object.entries(links ?? {})
		.map(([label, href]) => ({
			label: isGithubUrl(href) ? 'GitHub' : label,
			href,
		}))
		.sort((a, b) => Number(isGithubUrl(b.href)) - Number(isGithubUrl(a.href)));
	return app ? [{ label: appActionLabel(app.type), href: app.url }, ...projectLinks] : projectLinks;
}
