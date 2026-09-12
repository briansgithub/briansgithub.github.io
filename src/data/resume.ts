export const resume = {
	placeholder: false,
	summary:
		'Software engineer who ships production C/C++ firmware, Embedded Linux projects. 3.5 years of bare-metal microcontroller work. 1.5 years of electro-mechanical manufacturing experience managing the assembly, testing, and shipping of electromagnet assemblies. Agentically develops full-stack apps (Python, JavaScript, Node.js, REST) plus tested front ends and data layers (SQLite, OAuth). Strong in computer architecture, systems engineering (requirements, integration), data structures, Git, and hardware-software integration.',
	experience: [
		{
			role: 'Cofounder & Embedded Engineer',
			organization: 'Prong Technologies LLC',
			period: 'Jul 2021 — Dec 2024',
			location: 'Huntsville, AL',
			highlights: [
				'Wrote production C/C++ firmware for RP2040 bare-metal systems that drove HID and audio hardware, including deterministic I2S playback timing for TunePal.',
				'Built Python and Bash automation that generated production C/C++ and NAND flash memory maps, aligning software data layouts to hardware storage between design and integration.',
				'Isolated SPI/PCB faults in the lab. Managed Git deployments and authored the Superslab User Manual and Jabslab User Manual.',
			],
		},
		{
			role: 'Project Engineer',
			organization: 'Everson Tesla Inc.',
			period: 'Jun 2018 — Feb 2020',
			location: 'Nazareth, PA',
			highlights: [
				'Oversaw the completion of $50K-$10M electromagnet assembly projects. Verified product conformance for national laboratories and defense contractors to MIL-STD.',
				'Architected a dynamic flat/hierarchical BOM for status and location tracking.',
				'Prepared quotations and documentation for customers, suppliers, CAD, manufacturing technicians, and QA.',
			],
		},
		{
			role: 'Undergraduate Physics Researcher',
			organization: 'Andrei Research Group',
			period: 'Jun 2017 — May 2018',
			location: 'Piscataway, NJ',
			highlights: [
				'Applied data-driven optimization to CVD growth of monocrystalline graphene, increasing crystal diameter by an order of magnitude. Presented research findings at APS March Meeting 2018.',
			],
		},
	],
	projects: [
		{
			name: 'TideTracker',
			summary: 'Embedded Linux and NOAA data telemetry.',
			period: '2023',
			href: '/projects/tide-tracker/',
			highlights: [
				'Solar-powered e-ink display plotting real-time tidal data. Raspberry Pi Zero fetches NOAA tide data every two hours, draws an at-a-glance chart, then cuts its own power. Setup switch brings up a local hotspot AP so that settings can be configured via smartphone.',
			],
		},
		{
			name: 'LarkBridge',
			summary:
				'Raspberry Pi headset hardware emulation. Audio bridge for independent audio channel routing.',
			period: '2026 — Present',
			highlights: [
				'Pi 3B USB/Bluetooth headset bridge with mic failover, power-loss-hardened read-only root, and measured AEC acceptance tests.',
			],
		},
		{
			name: 'Acquiring',
			summary: 'Three-platform music-theory and ear-training apps.',
			period: '2025 — Present',
			href: '/projects/acquiring/',
			highlights: [
				'Native web (JavaScript/Tone.js), Android (Kotlin/Jetpack Compose), and iOS (Swift/SwiftUI) clients that share SQLite catalog contracts and behavioral fixtures instead of a common runtime.',
			],
		},
	],
	education: [
		{
			credential: 'B.S. Electrical & Computer Engineering',
			institution: 'Rutgers University, New Brunswick, NJ',
			period: '2018',
			details: 'Honors, Cum Laude. FPGA capstone (3rd in graduating class).',
		},
		{
			credential: 'B.S. Applied Physics, Minor in Computer Science',
			institution: 'Rutgers University, New Brunswick, NJ',
			period: '2018',
			details: 'Physics Departmental Honors, Cum Laude.',
		},
	],
	skills: [
		{
			category: 'Languages',
			items: ['C/C++', 'Python', 'Bash', 'PowerShell'],
		},
		{
			category: 'Embedded & real-time',
			items: [
				'Bare-metal firmware',
				'RP2040',
				'ESP8266',
				'Raspberry Pi Embedded Linux',
				'I2S',
				'DMA',
				'SPI',
				'Deterministic timing',
				'USB/Bluetooth',
				'NAND flash memory maps',
				'Soldering',
			],
		},
		{
			category: 'Tools & test',
			items: [
				'Git',
				'GitHub',
				'VS Code',
				'Unit/regression/HIL testing',
				'Linux (Debian, Manjaro)',
				'DMM',
				'Oscilloscope',
				'Logic analyzer',
				'KiCad',
				'LTspice',
				'SolidWorks',
			],
		},
		{
			category: 'Agentic tools',
			items: ['Cursor', 'Claude Code', 'Codex', 'Antigravity'],
		},
	],
} as const;
