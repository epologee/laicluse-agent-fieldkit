(function (root, factory) {
	const api = factory();
	if (typeof module === "object" && module.exports) {
		module.exports = api;
	} else {
		root.AgentCommandSwitch = api;
		if (root.document) {
			root.document.addEventListener("DOMContentLoaded", () => api.hydrate(root.document));
		}
	}
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
	"use strict";

	const storageKey = "agent-fieldkit.agent";
	const agents = [
		{
			id: "claude",
			label: "Claude",
			icon: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3.5a8.5 8.5 0 0 0-7.3 12.86L3.75 20.25l3.89-.95A8.5 8.5 0 1 0 12 3.5Zm-3.2 7.1h6.4M8.8 13.4h3.8" /></svg>',
		},
		{
			id: "codex",
			label: "Codex",
			icon: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4.75 6.75h14.5v10.5H4.75zM8 10l2 2-2 2m4.5 0h3.5" /></svg>',
		},
	];

	function escapeHtml(value) {
		return String(value || "")
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	function normalizedCommands(commands) {
		return agents
			.map((agent) => ({
				...agent,
				commands: Array.isArray(commands && commands[agent.id]) ? commands[agent.id].filter(Boolean) : [],
			}))
			.filter((agent) => agent.commands.length > 0);
	}

	function render(config) {
		const availableAgents = normalizedCommands(config.commands);
		if (availableAgents.length === 0) return "";
		const defaultAgent = availableAgents.some((agent) => agent.id === config.defaultAgent)
			? config.defaultAgent
			: availableAgents[0].id;
		const id = escapeHtml(config.id || `agent-command-${Math.random().toString(36).slice(2)}`);
		const label = escapeHtml(config.label || "Terminal commands");
		const optionMarkup =
			availableAgents.length > 1
				? `<div class="agent-command-options" role="group" aria-label="${label}">
${availableAgents
	.map((agent) => {
		const active = agent.id === defaultAgent;
		return `<button class="agent-command-option${active ? " is-active" : ""}" type="button" data-agent-option="${agent.id}" aria-pressed="${active ? "true" : "false"}">${agent.icon}<span>${escapeHtml(agent.label)}</span></button>`;
	})
	.join("\n")}
</div>`
				: `<div class="agent-command-single" aria-label="${label}">${availableAgents[0].icon}<span>${escapeHtml(availableAgents[0].label)}</span></div>`;
		const panels = availableAgents
			.map((agent) => {
				const active = agent.id === defaultAgent;
				return `<pre class="agent-command-panel${active ? " is-active" : ""}" data-agent-panel="${agent.id}"${active ? "" : " hidden"}><code id="${id}-${agent.id}">${escapeHtml(agent.commands.join("\n"))}</code></pre>`;
			})
			.join("\n");

		return `<div class="agent-command-switch" data-agent-command-switch data-default-agent="${defaultAgent}">
	<div class="agent-command-switch-head">
		${optionMarkup}
		<button class="agent-command-copy" type="button" data-agent-copy>Copy</button>
	</div>
	<div class="agent-command-panels">
${panels}
	</div>
</div>`;
	}

	function preferredAgent() {
		try {
			return localStorage.getItem(storageKey);
		} catch (_error) {
			return "";
		}
	}

	function storeAgent(agent) {
		try {
			localStorage.setItem(storageKey, agent);
		} catch (_error) {
			return;
		}
	}

	function setActive(switchElement, agent) {
		const panels = Array.from(switchElement.querySelectorAll("[data-agent-panel]"));
		const available = panels.map((panel) => panel.dataset.agentPanel);
		const nextAgent = available.includes(agent) ? agent : switchElement.dataset.defaultAgent || available[0];
		panels.forEach((panel) => {
			const active = panel.dataset.agentPanel === nextAgent;
			panel.hidden = !active;
			panel.classList.toggle("is-active", active);
		});
		switchElement.querySelectorAll("[data-agent-option]").forEach((button) => {
			const active = button.dataset.agentOption === nextAgent;
			button.classList.toggle("is-active", active);
			button.setAttribute("aria-pressed", active ? "true" : "false");
		});
	}

	function setAll(rootElement, agent) {
		rootElement.querySelectorAll("[data-agent-command-switch]").forEach((switchElement) => {
			setActive(switchElement, agent);
		});
	}

	async function copyText(text) {
		if (globalThis.CodePanelCopy) {
			await globalThis.CodePanelCopy.copyText(text);
			return;
		}
		if (navigator.clipboard) await navigator.clipboard.writeText(text);
	}

	function markCopied(button) {
		if (globalThis.CodePanelCopy) {
			globalThis.CodePanelCopy.markButtonCopied(button);
			return;
		}
		button.textContent = "Copied";
		window.setTimeout(() => {
			button.textContent = "Copy";
		}, 1400);
	}

	function hydrate(rootElement) {
		const rootNode = rootElement || document;
		const initialAgent = preferredAgent();
		if (initialAgent) setAll(rootNode, initialAgent);
		rootNode.querySelectorAll("[data-agent-command-switch]").forEach((switchElement) => {
			if (switchElement.dataset.agentCommandHydrated === "true") return;
			switchElement.dataset.agentCommandHydrated = "true";
			switchElement.addEventListener("click", async (event) => {
				const option = event.target.closest("[data-agent-option]");
				if (option) {
					storeAgent(option.dataset.agentOption);
					setAll(document, option.dataset.agentOption);
					return;
				}
				const copyButton = event.target.closest("[data-agent-copy]");
				if (!copyButton) return;
				const activePanel = switchElement.querySelector("[data-agent-panel].is-active code");
				if (!activePanel) return;
				await copyText(activePanel.textContent);
				markCopied(copyButton);
			});
		});
	}

	return { hydrate, render };
});
