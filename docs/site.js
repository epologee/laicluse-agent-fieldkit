(function () {
	const canvas = document.getElementById("field-map");
	if (!canvas) return;

	const context = canvas.getContext("2d");
	const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
	const colors = ["#0f766e", "#2457b8", "#a36a16", "#b42318"];
	const labels = [
		"git-discipline",
		"rover",
		"bonsai",
		"gurus",
		"drydry",
		"dibs",
		"intervision",
		"clipboard",
		"naming-is-hard",
		"self-improvement",
		"dont-do-that",
		"how-plugins-work",
	];

	let width = 0;
	let height = 0;
	let ratio = 1;
	let nodes = [];
	let frame = 0;

	function resize() {
		ratio = Math.max(1, window.devicePixelRatio || 1);
		width = canvas.clientWidth;
		height = canvas.clientHeight;
		canvas.width = Math.floor(width * ratio);
		canvas.height = Math.floor(height * ratio);
		context.setTransform(ratio, 0, 0, ratio, 0, 0);
		nodes = labels.map((label, index) => {
			const column = index % 4;
			const row = Math.floor(index / 4);
			return {
				label,
				x: width * (0.52 + column * 0.11) + Math.sin(index) * 18,
				y: height * (0.22 + row * 0.22) + Math.cos(index * 1.8) * 22,
				r: 4 + (index % 3),
				color: colors[index % colors.length],
				phase: index * 0.7,
			};
		});
		draw();
	}

	function draw() {
		context.clearRect(0, 0, width, height);
		context.lineCap = "round";
		context.lineJoin = "round";

		const t = frame / 60;
		for (let i = 0; i < nodes.length; i += 1) {
			for (let j = i + 1; j < nodes.length; j += 1) {
				if ((i + j) % 5 !== 0 && Math.abs(i - j) !== 4) continue;
				const a = nodes[i];
				const b = nodes[j];
				const pulse = 0.35 + Math.sin(t + a.phase + b.phase) * 0.12;
				context.strokeStyle = `rgba(20, 21, 20, ${pulse})`;
				context.lineWidth = 1;
				context.beginPath();
				context.moveTo(a.x, a.y);
				context.bezierCurveTo((a.x + b.x) / 2, a.y - 48, (a.x + b.x) / 2, b.y + 48, b.x, b.y);
				context.stroke();
			}
		}

		nodes.forEach((node, index) => {
			const drift = prefersReduced ? 0 : Math.sin(t + node.phase) * 3;
			const x = node.x + drift;
			const y = node.y + Math.cos(t * 0.8 + node.phase) * 2;
			context.fillStyle = "rgba(255, 255, 255, 0.78)";
			context.strokeStyle = "rgba(20, 21, 20, 0.16)";
			context.lineWidth = 1;
			const w = Math.max(92, node.label.length * 7.6 + 28);
			const h = 34;
			const rx = x - w / 2;
			const ry = y - h / 2;
			roundRect(rx, ry, w, h, 8);
			context.fill();
			context.stroke();

			context.fillStyle = node.color;
			context.beginPath();
			context.arc(rx + 15, y, node.r, 0, Math.PI * 2);
			context.fill();

			context.fillStyle = "#232722";
			context.font = "700 12px Inter, system-ui, sans-serif";
			context.fillText(node.label, rx + 28, y + 4);

			if (index % 4 === 0) {
				context.fillStyle = "rgba(163, 106, 22, 0.08)";
				context.beginPath();
				context.arc(x, y, 70, 0, Math.PI * 2);
				context.fill();
			}
		});

		if (!prefersReduced) {
			frame += 1;
			requestAnimationFrame(draw);
		}
	}

	function roundRect(x, y, w, h, r) {
		context.beginPath();
		context.moveTo(x + r, y);
		context.lineTo(x + w - r, y);
		context.quadraticCurveTo(x + w, y, x + w, y + r);
		context.lineTo(x + w, y + h - r);
		context.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
		context.lineTo(x + r, y + h);
		context.quadraticCurveTo(x, y + h, x, y + h - r);
		context.lineTo(x, y + r);
		context.quadraticCurveTo(x, y, x + r, y);
		context.closePath();
	}

	window.addEventListener("resize", resize);
	resize();
})();
