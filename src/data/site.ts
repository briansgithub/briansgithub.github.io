export const site = {
	name: 'bellsworth.dev',
	title: 'About Brian Ellsworth',
	description: 'Computer engineer writing about topics he finds interesting.',
	// tagline: 'Firmware Engineer',
	shortBio:
		'My background is in applied physics and computer engineering. This site is a collection of things I have done and that I enjoy: projects, technical writing, book notes, and quotations.',
	longBio:
		'I am a hardware engineer from New Jersey with experience in embedded software, manufacturing, start up companies, and project management. I am most proficient in Python and ANSI C. I have been using agentic tools to help me create closed-loop hardware test benches and develop in languages that I am unfamiliar with, such as Kotlin and Swift, in order to create fun and practical apps, like a 24-hour clock wallpaper (auto-synced daily with FitBit sleep data), heartrate-controlled software, and a powerful musical ear training practice app for iOS/Android.',
	url: 'https://bellsworth.dev',
	language: 'en-US',
	github: 'https://github.com/briansgithub',
	email: 'bellsworth137@gmail.com',
	linkedin: 'https://www.linkedin.com/in/brian-ellsworth/',
	instagram: 'https://www.instagram.com/bellsworth137/',
	preview: false,
} as const;

export const navigation = [
	{ label: 'About', href: '/' },
	{ label: 'Blog', href: '/blog/' },

	// Temporarily hidden
	// {
	// 	label: 'Collections',
	// 	href: '/collections/',
	// 	matchPrefixes: ['/prints/', '/books/', '/quotes/', '/tags/'],
	// },

	{ label: 'Projects', href: '/projects/' },
	{ label: 'Résumé', href: '/resume/' },
] as const;
