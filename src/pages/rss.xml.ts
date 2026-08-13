import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import { site } from '../data/site';
import { contentSlug } from '../utils/content';

export async function GET(context: { site?: URL }) {
	const entries = (
		await getCollection('writing', ({ data }) => !data.draft && !data.placeholder)
	).sort((a, b) => b.data.publishedAt.valueOf() - a.data.publishedAt.valueOf());
	return rss({
		title: site.title,
		description: site.description,
		site: context.site ?? site.url,
		items: entries.map((entry) => ({
			title: entry.data.title,
			description: entry.data.description,
			pubDate: entry.data.publishedAt,
			link: `/blog/${contentSlug(entry.id)}/`,
		})),
	});
}
