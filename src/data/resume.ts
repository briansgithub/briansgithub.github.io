export const resume = {
	placeholder: true,
	summary:
		'[PLACEHOLDER] A focused professional summary—two or three sentences connecting your computer engineering and physics background to the work you want to do.',
	experience: [
		{
			role: '[Role or position]',
			organization: '[Organization]',
			period: '[Start — End]',
			location: '[Location or remote]',
			highlights: [
				'[Describe a specific problem, your action, and the result.]',
				'[Add a measurable outcome where one genuinely exists.]',
			],
		},
	],
	education: [
		{
			credential: '[Computer engineering degree]',
			institution: '[Institution]',
			period: '[Dates]',
			details: '[Optional: honors, concentration, research, or selected coursework.]',
		},
		{
			credential: '[Physics degree]',
			institution: '[Institution]',
			period: '[Dates]',
			details: '[Optional: honors, concentration, research, or selected coursework.]',
		},
	],
	skills: [
		{ category: 'Programming', items: ['[Language]', '[Tool]', '[Framework]'] },
		{ category: 'Hardware & systems', items: ['[Platform]', '[Instrumentation]', '[Workflow]'] },
		{ category: 'Analysis', items: ['[Method]', '[Simulation]', '[Visualization]'] },
	],
} as const;
