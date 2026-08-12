export type VisibilityData = {
	draft?: boolean;
	placeholder?: boolean;
};

export function isContentVisible(data: VisibilityData, preview: boolean) {
	return !data.draft && (preview || !data.placeholder);
}
