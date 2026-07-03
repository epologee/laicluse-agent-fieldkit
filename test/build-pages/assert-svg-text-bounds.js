#!/usr/bin/env node

const fs = require("fs");

const svgPath = process.argv[2];
if (!svgPath) {
	console.error("usage: assert-svg-text-bounds.js <svg>");
	process.exit(2);
}

const svg = fs.readFileSync(svgPath, "utf8");

function attribute(markup, name) {
	const match = markup.match(new RegExp(`\\b${name}="([^"]+)"`));
	return match ? match[1] : null;
}

let checked = 0;
const failures = [];
const textPattern = /<text\b([^>]*)>([^<]*)<\/text>/g;

for (const match of svg.matchAll(textPattern)) {
	const maxWidth = Number(attribute(match[1], "data-max-width"));
	if (!maxWidth) continue;

	checked += 1;
	const fontSize = Number(attribute(match[1], "font-size"));
	const widthFactor = Number(attribute(match[1], "data-width-factor"));
	const label = match[2].replace(/&[^;]+;/g, "x");
	const estimatedWidth = label.length * fontSize * widthFactor;

	if (!fontSize || !widthFactor) {
		failures.push(`${label}: missing font-size or data-width-factor`);
	} else if (estimatedWidth > maxWidth) {
		failures.push(`${label}: ${estimatedWidth.toFixed(1)} > ${maxWidth}`);
	}
}

if (checked === 0) {
	failures.push("no data-max-width text elements found");
}

if (failures.length > 0) {
	console.error(failures.join("\n"));
	process.exit(1);
}
