<script>
	import { getDisplayTime, currentChat, currentGame } from '$lib/appData';
	import { onMount } from 'svelte';

	let bubble = null;
	export let id = '';

	export let gameData = {
		playerTurn: 0,
		timestamp: 20.0
	};

	$: if (gameData) {
		if ($currentGame.id === id) {
			//set the game
			setGame();
		}
	}

	$: isTurnBased =
		Object.keys(gameData).includes('gameState') &&
		Object.keys(gameData.gameState).includes('playerTurn');

	$: isRoundPlay =
		Object.keys(gameData).includes('gameState') &&
		Object.keys(gameData.gameState).includes('round');

	let fromYou = false;
	$: if (isTurnBased) {
		fromYou = gameData.gameState.playerTurn != $currentChat.playerIndex;
	}

	$: oppName = $currentChat.isGroup
		? Object.values($currentChat.members)[gameData.playerTurn]
		: 'Them';
	$: whoPlaying = fromYou ? oppName : 'You';
	$: timestamp = getDisplayTime(gameData.timestamp);

	function setGame() {
		$currentGame = { id, gameData, isTurnBased };
	}

	import { createEventDispatcher } from 'svelte';
	const dispatch = createEventDispatcher();
</script>

<button
	on:click={() => {
		setGame();
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
			<span class="w-fit">{gameData.name}</span>
			{#if isRoundPlay}
				<span class="text-base w-fit">Round {gameData.gameState.round}</span>
			{/if}
		</div>
	</div>
</button>
