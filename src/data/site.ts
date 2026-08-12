export const site = {
	name: 'Brian Ellsworth',
	title: 'Brian Ellsworth — Projects & Notes',
	description:
		'Software and embedded engineer writing about hardware builds, physics, and the tools between them.',
	tagline: 'Embedded and software engineer with a physics research background.',
	shortBio:
		'I build embedded systems and write software, with a background in applied physics and electrical engineering. This site collects hardware projects, technical writing, book notes, and quotations.',
	longBio:
		'I work across embedded software, project engineering, and hardware-software integration — most recently building bare-metal C/C++ firmware for RP2040-based devices and, before that, managing the electromechanical manufacturing of products from prototype through production. My background is in applied physics and electrical/computer engineering, with undergraduate research in graphene material characterization.',
	url: 'https://bellsworth.dev',
	language: 'en-US',
	github: 'https://github.com/briansgithub',
	email: 'bellsworth137@gmail.com',
	linkedin: 'https://www.linkedin.com/in/brian-ellsworth/',
	instagram: 'https://www.instagram.com/bellsworth137/',
	preview: true,
} as const;

export const navigation = [
	{ label: 'Projects', href: '/projects/' },
	{ label: 'Writing', href: '/writing/' },
	{
		label: 'Collections',
		href: '/collections/',
		matchPrefixes: ['/prints/', '/books/', '/quotes/', '/tags/'],
	},
	{ label: 'About', href: '/about/' },
	{ label: 'Résumé', href: '/resume/' },
] as const;
