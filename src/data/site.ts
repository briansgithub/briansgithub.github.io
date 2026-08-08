export const site = {
	name: '[Your Name]',
	title: '[Your Name] — Projects & Notes',
	description:
		'[PLACEHOLDER] A concise sentence describing what you build, study, and write about.',
	tagline: '[PLACEHOLDER] Computer engineer, physics graduate, and curious builder.',
	shortBio:
		'[PLACEHOLDER] A two- or three-sentence introduction that gives readers a clear sense of your work and interests.',
	longBio:
		'[PLACEHOLDER] Expand this into a short personal biography: what you care about, the kinds of problems you enjoy, and why you keep this site.',
	url: 'https://briansgithub.github.io',
	language: 'en-US',
	github: 'https://github.com/briansgithub',
	email: '',
	linkedin: '',
	preview: true,
} as const;

export const navigation = [
	{ label: 'Writing', href: '/writing/' },
	{ label: 'Projects', href: '/projects/' },
	{ label: 'Books', href: '/books/' },
	{ label: 'Quotes', href: '/quotes/' },
	{ label: 'About', href: '/about/' },
	{ label: 'Résumé', href: '/resume/' },
] as const;
