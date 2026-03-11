<script>
	import { slide } from 'svelte/transition';

	export let src;
	//this is the highlight source
	export let alt;
	export let label = 'BallSack';
	export let enabled = true;

	let isHovered = false;
</script>

<button on:mouseenter={() => (isHovered = true)} on:mouseleave={() => (isHovered = false)} on:click>
	<img {src} class="icon" {alt} />
	{#if isHovered && enabled}
		<span transition:slide={{ axis: 'x', duration: 250 }}>{label}</span>
	{/if}
</button>

<style>
	button {
		border: none;
		background-color: transparent;

		display: flex;
		gap: 2px;
		align-items: center;

		height: 100%;
		width: 100%;

		padding: 0;
		cursor: pointer;
		white-space: nowrap;
	}

	span {
		font-weight: 600;
		color: rgba(255, 255, 255, 0.311);

		font-family: 'Funnel Display', sans-serif;
	}

	.icon {
		width: 20px;
		height: 18px;

		margin: 0 8px;
	}
</style>
