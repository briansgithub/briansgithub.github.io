import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const tag = z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);
const editorialFields = {
	draft: z.boolean().default(true),
	placeholder: z.boolean().default(false),
};

const writing = defineCollection({
	loader: glob({ base: './src/content/writing', pattern: '**/*.{md,mdx}' }),
	schema: z.object({
		title: z.string().min(1).max(120),
		description: z.string().min(1).max(240),
		publishedAt: z.coerce.date(),
		updatedAt: z.coerce.date().optional(),
		tags: z.array(tag).default([]),
		featured: z.boolean().default(false),
		...editorialFields,
	}),
});

const projects = defineCollection({
	loader: glob({ base: './src/content/projects', pattern: '**/*.{md,mdx}' }),
	schema: ({ image }) =>
		z.object({
			title: z.string().min(1).max(120),
			summary: z.string().min(1).max(240),
			status: z.enum(['active', 'complete', 'archived']),
			year: z.number().int().min(1900).max(2200),
			technologies: z.array(z.string()).default([]),
			tags: z.array(tag).default([]),
			featured: z.boolean().default(false),
			cover: z
				.object({
					image: image(),
					alt: z.string().min(1).max(240),
				})
				.optional(),
			links: z.record(z.string(), z.url()).optional(),
			order: z.number().int().optional(),
			...editorialFields,
		}),
});

const books = defineCollection({
	loader: glob({ base: './src/content/books', pattern: '**/*.{md,mdx}' }),
	schema: z.object({
		title: z.string().min(1).max(120),
		author: z.string().min(1).max(120),
		summary: z.string().min(1).max(240),
		rating: z.number().int().min(1).max(5).optional(),
		finishedAt: z.coerce.date().optional(),
		tags: z.array(tag).default([]),
		...editorialFields,
	}),
});

const quotes = defineCollection({
	loader: glob({ base: './src/content/quotes', pattern: '**/*.{md,mdx}' }),
	schema: z.object({
		quote: z.string().min(1),
		author: z.string().min(1),
		source: z.string().optional(),
		url: z.url().optional(),
		category: z.string().optional(),
		order: z.number().int().optional(),
		...editorialFields,
	}),
});

const pages = defineCollection({
	loader: glob({ base: './src/content/pages', pattern: '**/*.{md,mdx}' }),
	schema: z.object({
		title: z.string().min(1).max(120),
		description: z.string().min(1).max(240),
		...editorialFields,
	}),
});

const prints = defineCollection({
	loader: glob({ base: './src/content/prints', pattern: '**/*.{md,mdx}' }),
	schema: z.object({
		title: z.string().min(1).max(120),
		summary: z.string().min(1).max(240),
		material: z.string().min(1).max(60),
		printedAt: z.coerce.date().optional(),
		tags: z.array(tag).default([]),
		featured: z.boolean().default(false),
		order: z.number().int().optional(),
		model: z
			.object({
				file: z.string(),
				sizeBytes: z.number().int().positive(),
			})
			.optional(),
		links: z.record(z.string(), z.url()).optional(),
		...editorialFields,
	}),
});

export const collections = { writing, projects, books, quotes, pages, prints };
