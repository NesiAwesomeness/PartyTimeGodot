<script>
	import { app } from '$lib/app.svelte';
	import { getDisplayTime } from '$lib/appData';
	import { onMount } from 'svelte';

	let bubble = null;
	let { id, gameInfo } = $props();

	let isTurnBased = $derived(Object.keys(gameInfo).includes('turn'));
	let isRoundPlay = $derived(Object.keys(gameInfo).includes('round'));

	let fromYou = $derived(isTurnBased ? gameInfo.turn != app.currentChat.playerIndex : true);

	let oppName = $derived(
		app.currentChat.isGroup ? Object.values(app.currentChat.members)[gameInfo.turn] : 'Them'
	);

	let whoPlaying = $derived(fromYou ? oppName : 'You');
	let timestamp = $derived(getDisplayTime(gameInfo.timestamp));

	import { createEventDispatcher } from 'svelte';
	const dispatch = createEventDispatcher();
</script>

<button
	onclick={() => {
		app.setGame({ id, gameInfo });
		dispatch('click', bubble);
	}}
	class="flex w-full aspect-[100/40] max-h-[160px] min-w-[240px] cursor-pointer font-['Funnel_Display',sans-serif] bg-black/[0.135] border-none p-0 {fromYou
		? 'flex-row-reverse rounded-t-2xl rounded-bl-2xl rounded-br-lg'
		: 'flex-row rounded-t-2xl rounded-bl-lg rounded-br-2xl'}"
>
	<div
		bind:this={bubble}
		class="bg-[#171717] h-full aspect-[100/80] max-w-[200px] z-[1] {fromYou
			? 'rounded-t-2xl rounded-bl-2xl rounded-br-lg'
			: 'rounded-t-2xl rounded-bl-lg rounded-br-2xl'}"
	></div>
	<div
		class="flex flex-col relative gap-1 h-full min-w-[160px] max-w-[180px] p-4 box-border text-white/[0.527] bg-[#111111] rounded-xl {fromYou
			? 'left-6 pr-[42px]'
			: '-left-6 pl-[42px]'}"
	>
		<span class="text-xs w-fit m-0">{timestamp}</span>
		<span
			class="rounded-2xl w-fit px-2 font-medium text-xs text-white {fromYou
				? 'bg-[#454545]'
				: 'bg-[#cb4444]'}">{whoPlaying}</span
		>
		<div class="grid content-end h-full min-w-[90px] font-semibold text-xl text-white/[0.815]">
			<span class="w-fit">{gameInfo.name}</span>
			{#if isRoundPlay}
				<span class="text-base w-fit">Round {gameInfo.gameState.round}</span>
			{/if}
		</div>
	</div>
</button>
