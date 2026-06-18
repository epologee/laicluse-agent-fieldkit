(function () {
	"use strict";

	const state = {
		data: null,
		query: "",
		support: "all",
		category: "all",
	};

	const supportFilters = [
		{ id: "all", label: "All" },
		{ id: "both", label: "Claude + Codex" },
		{ id: "claude", label: "Claude only" },
	];

	const typeClass = {
		Breaking: "breaking",
		Added: "added",
		Changed: "changed",
		Fixed: "fixed",
	};

	function $(selector) {
		return document.querySelector(selector);
	}

	function escapeHtml(value) {
		return String(value || "")
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	function plural(count, word) {
		return `${count} ${word}${count === 1 ? "" : "s"}`;
	}

	function supportLabel(plugin) {
		return plugin.codex ? "Claude + Codex" : "Claude only";
	}

	function supportMode(plugin) {
		return plugin.codex ? "both" : "claude";
	}

	function categoryLabel(id) {
		const category = state.data.categories.find((item) => item.id === id);
		return category ? category.label : id;
	}

	function renderHero(data) {
		$("#hero-stats").innerHTML = `
			<div class="stat-row">
				<strong>${data.counts.sourcePackages}</strong>
				<span>source packages</span>
			</div>
			<div class="stat-row">
				<strong>${data.counts.codexPackages}</strong>
				<span>Codex-compatible adapters</span>
			</div>
			<div class="stat-row muted">
				<strong>${data.counts.claudeOnlyPackages}</strong>
				<span>Claude-only packages</span>
			</div>
			<div class="stat-row">
				<strong>${data.counts.skillEntries}</strong>
				<span>skill entries indexed</span>
			</div>
		`;

		const latest = data.changelog[0];
		$("#hero-change").innerHTML = latest
			? `
				<span class="mini-label">latest package note</span>
				<strong>${escapeHtml(latest.plugin)} ${escapeHtml(latest.packageVersion)}</strong>
				<p>${escapeHtml(latest.summary)}</p>
			`
			: "";
	}

	function renderSummaries(data) {
		$("#catalog-summary").innerHTML = `
			<span>${plural(data.counts.sourcePackages, "package")}</span>
			<span>${plural(data.counts.codexPackages, "Codex adapter")}</span>
			<span>${plural(data.counts.changelogEntries, "changelog note")}</span>
		`;
	}

	function renderFilterButtons(container, filters, active, onSelect) {
		container.innerHTML = filters
			.map(
				(filter) => `
					<button type="button" data-filter="${escapeHtml(filter.id)}" aria-pressed="${filter.id === active}">
						${escapeHtml(filter.label)}
					</button>
				`,
			)
			.join("");
		container.querySelectorAll("button").forEach((button) => {
			button.addEventListener("click", () => {
				onSelect(button.dataset.filter);
			});
		});
	}

	function syncFilterButtons() {
		document.querySelectorAll("#support-filters button").forEach((button) => {
			button.setAttribute("aria-pressed", String(button.dataset.filter === state.support));
		});
		document.querySelectorAll("#category-filters button").forEach((button) => {
			button.setAttribute("aria-pressed", String(button.dataset.filter === state.category));
		});
	}

	function renderControls(data) {
		renderFilterButtons($("#support-filters"), supportFilters, state.support, (filter) => {
			state.support = filter;
			syncFilterButtons();
			renderCatalog();
		});

		renderFilterButtons(
			$("#category-filters"),
			[{ id: "all", label: "All categories" }, ...data.categories],
			state.category,
			(filter) => {
				state.category = filter;
				syncFilterButtons();
				renderCatalog();
			},
		);

		$("#catalog-search").addEventListener("input", (event) => {
			state.query = event.target.value.toLowerCase().trim();
			renderCatalog();
		});
	}

	function pluginMatches(plugin) {
		if (state.support !== "all" && supportMode(plugin) !== state.support) return false;
		if (state.category !== "all" && plugin.category !== state.category) return false;
		if (!state.query) return true;
		const haystack = [
			plugin.name,
			plugin.summary,
			categoryLabel(plugin.category),
			supportLabel(plugin),
			plugin.latestChange && plugin.latestChange.summary,
		]
			.filter(Boolean)
			.join(" ")
			.toLowerCase();
		return haystack.includes(state.query);
	}

	function renderCatalog() {
		const grid = $("#plugin-grid");
		const plugins = state.data.plugins.filter(pluginMatches);
		$("#empty-state").hidden = plugins.length > 0;
		grid.innerHTML = plugins.map(renderPluginCard).join("");
	}

	function renderPluginCard(plugin) {
		const change = plugin.latestChange;
		const type = change ? change.type : "Changed";
		const badgeClass = typeClass[type] || "changed";
		const featureBits = [
			plural(plugin.skillCount, "skill"),
			plugin.commandCount ? plural(plugin.commandCount, "command") : null,
			plugin.hookFileCount ? "hooks" : null,
		].filter(Boolean);

		return `
			<article class="plugin-card">
				<header class="plugin-head">
					<div>
						<p class="plugin-category">${escapeHtml(categoryLabel(plugin.category))}</p>
						<h3>${escapeHtml(plugin.name)}</h3>
					</div>
					<span class="version-pill">${escapeHtml(plugin.version)}</span>
				</header>
				<p class="plugin-summary">${escapeHtml(plugin.summary)}</p>
				<div class="plugin-meta" aria-label="Package metadata">
					<span class="support-pill ${supportMode(plugin)}">${escapeHtml(supportLabel(plugin))}</span>
					${featureBits.map((bit) => `<span>${escapeHtml(bit)}</span>`).join("")}
				</div>
				${
					change
						? `
							<div class="latest-note">
								<span class="change-type ${badgeClass}">${escapeHtml(type)}</span>
								<p>${escapeHtml(change.summary)}</p>
							</div>
						`
						: ""
				}
				<a class="source-link" href="${escapeHtml(plugin.sourceUrl)}">Package source</a>
			</article>
		`;
	}

	function renderInstall(data) {
		$("#claude-install").textContent = data.install.claude.join("\n");
		$("#codex-install").textContent = data.install.codex.join("\n");
		document.querySelectorAll("[data-copy-target]").forEach((button) => {
			button.addEventListener("click", async () => {
				const target = document.getElementById(button.dataset.copyTarget);
				if (!target || !navigator.clipboard) return;
				await navigator.clipboard.writeText(target.textContent);
				button.textContent = "Copied";
				window.setTimeout(() => {
					button.textContent = "Copy";
				}, 1400);
			});
		});
	}

	function renderChangelog(data) {
		$("#change-feed").innerHTML = data.changelog
			.map((change) => {
				const badgeClass = typeClass[change.type] || "changed";
				return `
					<article class="change-item">
						<div class="change-head">
							<div>
								<p>${escapeHtml(change.plugin)}</p>
								<h3>${escapeHtml(change.packageVersion)}</h3>
							</div>
							<span class="change-type ${badgeClass}">${escapeHtml(change.type)}</span>
						</div>
						<p>${escapeHtml(change.summary)}</p>
						<a href="${escapeHtml(change.sourceUrl)}">Full changelog</a>
					</article>
				`;
			})
			.join("");
	}

	function renderError(error) {
		$("#hero-stats").innerHTML = "<p>Catalog data could not be loaded.</p>";
		$("#plugin-grid").innerHTML = `
			<p class="error-state">
				${escapeHtml(error.message || "Unable to load docs/site-data.json.")}
			</p>
		`;
	}

	fetch("site-data.json")
		.then((response) => {
			if (!response.ok) throw new Error(`HTTP ${response.status}`);
			return response.json();
		})
		.then((data) => {
			state.data = data;
			renderHero(data);
			renderSummaries(data);
			renderControls(data);
			renderCatalog();
			renderInstall(data);
			renderChangelog(data);
		})
		.catch(renderError);
})();
