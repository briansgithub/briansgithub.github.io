export function contentSlug(id: string) {
	return id.replace(/\\/g, '/').replace(/\/index$/, '');
}

export function formatDate(date: Date) {
	return new Intl.DateTimeFormat('en-US', {
		year: 'numeric',
		month: 'long',
		day: 'numeric',
	}).format(date);
}

export function isVisible(data: { draft?: boolean }) {
	return !data.draft;
}
