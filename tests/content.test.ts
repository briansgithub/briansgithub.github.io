import assert from 'node:assert/strict';
import test from 'node:test';
import { isContentVisible } from '../src/utils/visibility.ts';

test('draft entries are never visible', () => {
	assert.equal(isContentVisible({ draft: true }, true), false);
	assert.equal(isContentVisible({ draft: true }, false), false);
});

test('placeholders are visible only in preview builds', () => {
	assert.equal(isContentVisible({ draft: false, placeholder: true }, true), true);
	assert.equal(isContentVisible({ draft: false, placeholder: true }, false), false);
});

test('published non-placeholder entries remain visible', () => {
	assert.equal(isContentVisible({ draft: false, placeholder: false }, false), true);
});
