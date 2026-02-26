<script>
	import { createEventDispatcher } from 'svelte';
	import { fade, fly } from 'svelte/transition';

	const dispatch = createEventDispatcher();

	// Props
	export let isOpen = false;
	let className = '';
	export { className as class };

	function close() {
		isOpen = false;
	}
</script>

{#if isOpen}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="fixed inset-0 z-[100] flex items-center justify-center bg-black/80"
		on:click={close}
		transition:fade={{ duration: 200 }}
	>
		<div
			class="relative w-full max-w-[400px] bg-[#212121] p-6 shadow-xl rounded-t-2xl sm:rounded-2xl {className}"
			on:click|stopPropagation
			transition:fly={{ y: 100, duration: 400 }}
		>
			<button
				aria-label="close"
				on:click={close}
				class="absolute right-4 top-4 text-xs font-medium text-white/60 hover:text-white tracking-wider"
			>
				<svg
					xmlns="http://www.w3.org/2000/svg"
					width="18"
					height="18"
					viewBox="0 0 24 24"
					fill="none"
					stroke="currentColor"
					stroke-width="2"
					stroke-linecap="round"
					stroke-linejoin="round"
					class="lucide lucide-x-icon lucide-x"><path d="M18 6 6 18" /><path d="m6 6 12 12" /></svg
				>
			</button>

			<div class="text-white">
				<slot />
			</div>
		</div>
	</div>
{/if}
