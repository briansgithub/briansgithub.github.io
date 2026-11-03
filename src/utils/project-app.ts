import { z } from 'astro/zod';

export const projectAppSchema = z.object({
	type: z.enum(['pwa', 'web-app', 'chrome-extension', 'android', 'ios', 'desktop', 'cli']),
	url: z.url(),
	note: z.string().min(1).max(240).optional(),
});
