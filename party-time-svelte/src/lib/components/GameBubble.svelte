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

	$: fromYou = gameData.playerTurn != $currentChat.playerIndex;
	$: oppName = $currentChat.isGroup
		? Object.values($currentChat.members)[gameData.playerTurn]
		: 'Them';
	$: whoPlaying = fromYou ? oppName : 'You';
	$: timestamp = getDisplayTime(gameData.timestamp);

	function setGame() {
		$currentGame = { id, gameData };
	}

	import { createEventDispatcher } from 'svelte';
	const dispatch = createEventDispatcher();
</script>

<button
	on:click={() => {
		setGame();
		dispatch('click', bubble);
	}}
	class="game-bubble"
	style="
	flex-direction: row{fromYou ? '-reverse' : ''};
	border-radius: 16px 16px {fromYou ? 8 : 16}px {fromYou ? 16 : 8}px;
	"
>
	<div
		bind:this={bubble}
		class="preview"
		style="border-radius: 16px 16px {fromYou ? 8 : 16}px {fromYou ? 16 : 8}px;"
	></div>
	<div
		class="game-info"
		style="
		left: {fromYou ? '' : '-'}24px;
		padding-{fromYou ? 'right' : 'left'}: 42px;"
	>
		<span class="timestamp">{timestamp}</span>
		<span
			class="member"
			style="background-color:{fromYou ? 'rgb(69, 69, 69)' : 'rgb(203, 68, 68)'};"
			>{whoPlaying}</span
		>
		<div class="game-title">
			<span class="game-name">{gameData.name}</span>
			{#if gameData.isRoundPlay}
				<span class="game-round">Round {gameData.round}</span>
			{/if}
		</div>
	</div>
</button>

<style>
	.preview {
		background-color: rgb(23, 23, 23);

		height: 100%;
		aspect-ratio: 100 / 80;

		max-width: 200px;

		z-index: 1;
	}

	.timestamp {
		font-size: 0.75rem;
		width: fit-content;
		margin: 0;
	}

	.member {
		background-color: rgb(203, 68, 68);
		border-radius: 16px;
		width: fit-content;

		padding: 0 8px;

		font-weight: 500;
		font-size: 0.75rem;

		color: white;
	}

	.game-title {
		display: grid;
		align-content: end;

		height: 100%;
		min-width: 90px;

		font-weight: 600;
		font-size: 1.25rem;
		color: rgba(255, 255, 255, 0.815);
	}

	.game-title span {
		width: fit-content;
	}

	.game-round {
		font-size: 1rem;
	}

	.game-info {
		display: flex;
		flex-direction: column;

		position: relative;
		gap: 4px;

		height: 100%;
		min-width: 160px;
		max-width: 180px;

		padding: 16px;
		box-sizing: border-box;

		color: rgba(255, 255, 255, 0.527);
		background-color: rgb(17, 17, 17);

		border-radius: 12px;
	}

	.game-bubble {
		display: flex;

		width: 100%;
		aspect-ratio: 100 / 40;
		max-height: 160px;

		min-width: 240px;

		cursor: pointer;

		font-family: 'Funnel Display', sans-serif;

		background-color: rgba(0, 0, 0, 0.135);
		border-radius: 12px;
		border: none;
		padding: 0;
	}
</style>
