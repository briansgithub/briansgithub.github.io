export const resume = {
	placeholder: false,
	summary:
		'Software engineer with experience in embedded software, project engineering, product development, lab research, and manufacturing of electro-mechanical devices. Skilled in defining product specifications and developing software for both front- and back-end applications, with a detail-oriented approach to risk and security analysis. Known for driving designs from concept through implementation, ensuring compliance with industry standards, and collaborating effectively across disciplines.',
	experience: [
		{
			role: 'Embedded Engineer',
			organization: 'Prong Technologies LLC',
			period: 'Jul 2021 — Dec 2024',
			location: 'Huntsville, AL',
			highlights: [
				'Developed embedded C/C++ software for RP2040-based, bare-metal embedded systems, and created Python scripts to generate production-ready C/C++ code and memory maps for NAND flash integration.',
				'Tested the web UI of a self-hosted settings configuration page on flagship products, including HID devices for professional arcade gaming.',
				'Authored and maintained product documentation, assembly guides, and testing procedures to support production workflows, including the Superslab User Manual at prong.studio/superslab/manual.',
				'Debugged PCBs using DMM and oscilloscope lab equipment to identify defective boards and resolve critical issues.',
				'Enhanced company operations through the design and manufacture of tooling apparatuses and part prototypes using FDM/SLA 3D printing, laser cutting, and machining.',
			],
		},
		{
			role: 'Project Engineer',
			organization: 'Everson Tesla Inc.',
			period: 'Jun 2018 — Feb 2020',
			location: 'Nazareth, PA',
			highlights: [
				'Led cross-functional teams — customers, suppliers, procurement, CAD engineers, manufacturing technicians, and QA — to meet project requirements, schedules, budgets, and quality standards.',
				'Managed the end-to-end manufacturing of electromechanical products, overseeing projects with production volumes from 5 to 200 units and budgets ranging from $50K to $10M.',
				'Verified product reliability and quality through electrical and geometrical testing in compliance with MIL-STD specifications, and drove project outcomes by maintaining schedules, BOMs, MPOs, test procedures, and QAs.',
				'Engineered CAD models in SolidWorks for tooling design and managed component procurement with suppliers.',
				'Reduced project delays and minimized part misplacement in large-scale, complex assemblies by optimizing BOM processes with a dynamic template featuring flat and hierarchical views, plus location and status tracking.',
			],
		},
		{
			role: 'Undergraduate Physics Researcher',
			organization: 'Andrei Research Group',
			period: 'Jun 2017 — May 2018',
			location: 'Piscataway, NJ',
			highlights: [
				'Improved material quality by optimizing graphene crystal diameter through CVD and electrochemical polishing techniques.',
				'Conducted microscopy-based research on graphene, contributing to material characterization and analysis for research advancements.',
				'Presented research at weekly group meetings and the APS March Meeting 2018.',
			],
		},
	],
	education: [
		{
			credential: 'B.S. Electrical & Computer Engineering',
			institution: 'Rutgers University, New Brunswick, NJ',
			period: '2018',
			details: '',
		},
		{
			credential: 'B.S. Applied Physics, minor Computer Science',
			institution: 'Rutgers University, New Brunswick, NJ',
			period: '2018',
			details: '',
		},
	],
	skills: [
		{
			category: 'Programming & scripting',
			items: ['C/C++', 'Python', 'JavaScript', 'Bash', 'PowerShell'],
		},
		{
			category: 'Electronics & hardware',
			items: [
				'Oscilloscope',
				'DMM',
				'LCR meter',
				'Digital logic analyzer',
				'Soldering',
				'PCB design',
				'Debugging SPI',
				'MIL-STD electrical testing',
			],
		},
		{
			category: 'Design, modeling & fabrication',
			items: [
				'SolidWorks',
				'OpenSCAD',
				'LTspice',
				'KiCad',
				'FDM & SLA 3D printing',
				'Circuit schematics',
			],
		},
		{
			category: 'Software & tooling',
			items: ['Git', 'VS Code', 'Cursor', 'SysPro ERP', 'Microsoft Project'],
		},
		{
			category: 'Operating systems',
			items: ['Manjaro Linux', 'Red Hat Linux', 'Windows'],
		},
	],
} as const;
