(function (root, factory) {
	const api = factory(root);
	if (typeof module === "object" && module.exports) {
		module.exports = api;
	} else {
		root.CodePanelCopy = api;
		if (root.document) {
			root.document.addEventListener("DOMContentLoaded", () => {
				api.hydrate(root.document);
				api.observe(root.document);
			});
		}
	}
})(typeof globalThis !== "undefined" ? globalThis : this, function (root) {
	"use strict";

	const icon =
		'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 5.75h8.25a1 1 0 0 1 1 1V17a1.25 1.25 0 0 1-1.25 1.25H9a1 1 0 0 1-1-1V6.75a1 1 0 0 1 1-1Z" /><path d="M6.75 15.75h-.5a1.5 1.5 0 0 1-1.5-1.5v-8A1.5 1.5 0 0 1 6.25 4.75h7" /></svg>';

	function fallbackCopy(text) {
		const textarea = root.document.createElement("textarea");
		textarea.value = text;
		textarea.setAttribute("readonly", "");
		textarea.style.position = "fixed";
		textarea.style.left = "-9999px";
		root.document.body.appendChild(textarea);
		textarea.select();
		try {
			root.document.execCommand("copy");
		} finally {
			textarea.remove();
		}
	}

	async function copyText(text) {
		if (root.navigator && root.navigator.clipboard) {
			await root.navigator.clipboard.writeText(text);
			return;
		}
		fallbackCopy(text);
	}

	function markButtonCopied(button, label = "Copy") {
		const text = button.querySelector("[data-copy-label]");
		if (text) text.textContent = "Copied";
		else button.textContent = "Copied";
		root.window.setTimeout(() => {
			if (text) text.textContent = label;
			else button.textContent = label;
		}, 1400);
	}

	function copyButton() {
		const button = root.document.createElement("button");
		button.className = "code-panel-copy";
		button.type = "button";
		button.setAttribute("aria-label", "Copy code");
		button.setAttribute("title", "Copy code");
		button.setAttribute("data-code-panel-copy", "");
		button.innerHTML = `${icon}<span data-copy-label>Copy</span>`;
		return button;
	}

	function hydrate(rootElement) {
		const rootNode = rootElement || root.document;
		rootNode.querySelectorAll("pre").forEach((pre) => {
			if (pre.dataset.codePanelCopyHydrated === "true") return;
			if (pre.closest("[data-agent-command-switch]")) return;
			const code = pre.querySelector("code");
			if (!code) return;
			pre.dataset.codePanelCopyHydrated = "true";
			pre.classList.add("code-panel");
			const button = copyButton();
			button.addEventListener("click", async () => {
				await copyText(code.textContent || "");
				markButtonCopied(button);
			});
			pre.appendChild(button);
		});
	}

	function observe(rootElement) {
		if (!root.MutationObserver || rootElement.dataset?.codePanelCopyObserved === "true") return;
		const target = rootElement.body || rootElement;
		if (!target) return;
		if (rootElement.dataset) rootElement.dataset.codePanelCopyObserved = "true";
		const observer = new root.MutationObserver((mutations) => {
			for (const mutation of mutations) {
				for (const node of mutation.addedNodes) {
					if (node.nodeType === 1) hydrate(node);
				}
			}
		});
		observer.observe(target, { childList: true, subtree: true });
	}

	return { copyText, hydrate, markButtonCopied, observe };
});
