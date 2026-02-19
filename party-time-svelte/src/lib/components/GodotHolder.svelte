<script>
	import { currentGame, currentChat } from '$lib/appData';
	import { rtdb } from '$lib/firebase';
	import { ref, update } from 'firebase/database';

	let isLoaded = false;
	let iframeGodot;
	export let isGameOpen = false;
	let lastUpdated = 0.0;

	$: if (isGameOpen) {
		gameUpdate('start_game');
	}

	//if any of the games change, this should run
	$: if ($currentGame) {
		gameUpdate('update_game');
	}

	function gameUpdate(functionName) {
		let members = {};

		if ($currentChat.members) {
			members = $currentChat.members;
		}

		const memberIds = Object.keys(members);
		pushGodot(functionName, {
			...$currentGame,
			chatData: {
				playerIndex: $currentChat.playerIndex,
				memberCount: memberIds.length,
				members: $currentChat.members
			}
		});
	}

	export let rect = {
		x: 0.0,
		y: 0.0,
		h: 1.0,
		w: 1.0,
		o: 0.0,
		r: 0.0
	};

	// sending to Godot
	function pushGodot(functionName, data) {
		const jsonString = JSON.stringify(data);
		if (iframeGodot && iframeGodot.contentWindow && iframeGodot.contentWindow.sendToGodot) {
			iframeGodot.contentWindow.sendToGodot(functionName, jsonString);
		}
	}

	function sendGame() {
		pushGodot('send_game', { timestamp: Date.now() });
	}

	// receiving from Godot.
	function pullGodot(event) {
		if (!event.data || !event.data.message) return;
		const message = event.data.message;
		const payload = event.data.data;

		console.log(event.data.message);

		switch (message) {
			case 'upload':
				uploadGame(payload);
		}

		// console.log(`Svelte received message: ${message}`, payload);
	}

	async function uploadGame(data) {
		let dataToSave = { ...data };

		// console.log(dataToSave, 'data');
		dataToSave.timestamp = Date.now();

		try {
			// Point directly to the specific game inside the chat
			const gameRef = ref(rtdb, `chats/${$currentChat.id}/games/${dataToSave.id}`);

			await update(gameRef, dataToSave);

			// console.log('Game turn advanced successfully!');
		} catch (error) {
			console.error('Failed to update game:', error);
		}
	}

	function closeGame() {
		pushGodot('on_game_close', {});
	}

	import { createEventDispatcher } from 'svelte';
	const dispatch = createEventDispatcher();
</script>

<svelte:window on:message={pullGodot} />

<div
	class="godot-holder"
	class:opened={isGameOpen}
	style="
	left: {rect.x}px;
	top: {rect.y}px;
	width: {rect.w}px;
	height: {rect.h}px;
	opacity: {rect.o};
	border-radius: {rect.r}px;
"
>
	<iframe
		bind:this={iframeGodot}
		src="/godot-build/index.html"
		title="Godot Game"
		on:load={() => (isLoaded = true)}
	>
	</iframe>
	<div class="buttons">
		<button
			title="Close Game"
			on:click={() => {
				closeGame();
				dispatch('click');
			}}
		>
			<svg
				viewBox="0 0 512 512"
				style="enable-background:new 0 0 512 512;"
				xml:space="preserve"
				width="42px"
				height="42px"
			>
				<path
					fill="#ffffff"
					d="M256,0C114.615,0,0,114.615,0,256s114.615,256,256,256s256-114.615,256-256C511.847,114.678,397.322,0.153,256,0z    M341.333,311.189c8.669,7.979,9.229,21.475,1.25,30.144c-7.979,8.669-21.475,9.229-30.144,1.25c-0.434-0.399-0.85-0.816-1.25-1.25   L256,286.165l-55.168,55.168c-8.475,8.185-21.98,7.95-30.165-0.525c-7.984-8.267-7.984-21.373,0-29.64L225.835,256l-55.168-55.168   c-8.185-8.475-7.95-21.98,0.525-30.165c8.267-7.984,21.373-7.984,29.64,0L256,225.835l55.189-55.168   c7.979-8.669,21.475-9.229,30.144-1.25c8.669,7.979,9.229,21.475,1.25,30.144c-0.399,0.434-0.816,0.85-1.25,1.25L286.165,256   L341.333,311.189z"
				/>
			</svg>
		</button>
		{#if $currentGame.gameData.isTurnBased}
			<button title="Send Game" style="background-color: cadetblue;" on:click={sendGame}>
				<svg
					xmlns="http://www.w3.org/2000/svg"
					height="28px"
					viewBox="0 -960 960 960"
					width="28px"
					fill="#e3e3e3"
					style="
					position: relative;
					top: 1px;
					left: 2px;
					"
					><path
						d="M176-183q-20 8-38-3.5T120-220v-180l320-80-320-80v-180q0-22 18-33.5t38-3.5l616 260q25 11 25 37t-25 37L176-183Z"
					/></svg
				>
			</button>
		{/if}
	</div>
</div>

<style>
	.godot-holder > iframe,
	.buttons {
		grid-area: 1 / 1;
	}

	.buttons {
		display: flex;
		position: absolute;

		flex-direction: column;
		justify-self: end;

		justify-content: space-between;

		height: calc(100vh - 72px);
		margin: 36px;
	}

	button {
		z-index: inherit;
		height: fit-content;
		box-sizing: border-box;

		border-radius: 50%;
		padding: 0;

		width: 42px;
		min-height: 42px;
		height: 42px;

		border: none;
		cursor: pointer;
	}

	.godot-holder {
		position: absolute;

		display: grid;
		grid-template-columns: 1fr;
		align-items: center;

		border: none;
		pointer-events: none;

		overflow: hidden;
		scrollbar-width: none;
		z-index: 0;

		box-sizing: border-box;
	}

	.godot-holder.opened {
		z-index: 2;
		overflow: hidden;
		pointer-events: auto;
	}

	iframe {
		border: none;
		width: 100%;
		height: 100%;
	}
</style>
