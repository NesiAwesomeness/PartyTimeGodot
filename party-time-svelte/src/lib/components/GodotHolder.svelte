<script>
	import { app, game } from '$lib/app.svelte';
	import { rtdb } from '$lib/firebase';
	import {
		child,
		get,
		increment,
		onChildAdded,
		onDisconnect,
		onValue,
		push,
		ref,
		remove,
		set,
		update
	} from 'firebase/database';
	import { broadcast, joinSession, leaveMeshSession, meshState, sendTo } from '$lib/webrtc';

	let isLoaded = $state(false);
	let iframeRef;

	let { rect = { x: 0.0, y: 0.0, h: 1.0, w: 1.0, o: 0.0, r: 0.0 } } = $props();
	let gameMovesUnsub;

	let isGameOpen = $derived(app.currentGame.id !== '');
	let isActive = false;
	let open = false;

	onMount(() => {
		window.removeEventListener('beforeunload', handleEmergencyCleanup);
	});

	function handleEmergencyCleanup(event) {
		leaveSession();
	}

	let gameLoading = $state(false);

	$effect(async () => {
		let members = {};

		if (app.currentChat?.members && isLoaded) {
			members = app.currentChat.members;
			const memberIds = Object.keys(members);

			pushGodot('update_chat', {
				playerIndex: app.currentChat.playerIndex,
				memberCount: memberIds.length,
				members,
				myID: app.uid
			});
		}

		if (game.gameRequest && isLoaded && !open) {
			pushGodot('initialize_game', game.gameRequest);
		}

		if (open != isGameOpen && iframeRef && iframeRef.contentWindow) {
			open = isGameOpen;

			gameLoading = true;

			if (isGameOpen) {
				const cw = iframeRef.contentWindow;
				console.log(app.currentGame.id);

				const gameStateRef = ref(
					rtdb,
					`chats/${app.currentChat.id}/gameState/${app.currentGame.id}`
				);

				const snapshot = await get(gameStateRef);

				if (snapshot.exists()) {
					let moveIndex = 0;

					const gameState = snapshot.val();
					const gameData = { ...gameState, ...app.currentGame.gameInfo };

					if (cw.startGame) {
						console.log(gameData);

						cw.startGame(gameData);
					}

					joinSession();

					const gameMovesRef = ref(
						rtdb,
						`chats/${app.currentChat.id}/gameMoves/${app.currentGame.id}/`
					);

					gameMovesUnsub = onChildAdded(gameMovesRef, (move) => {
						const newMove = move.val();
						if (newMove) {
							moveIndex++;
							cw.newMove(newMove);
						}
					});

					gameLoading = false;
				}
			}
		}
	});

	function closeGame() {
		const cw = iframeRef.contentWindow;
		cw.closeGame();
	}

	function handleIframeLoad() {
		if (!iframeRef || !iframeRef.contentWindow) return;
		isLoaded = true;

		const cw = iframeRef.contentWindow;

		//WebRTC stuff
		cw.GodotBroadcastData = (data) => {
			broadcast(data);
		};

		cw.GodotSendToPlayer = (targetPeerId, data) => {
			sendTo(targetPeerId, data);
		};

		//Firebase Stuff
		cw.makeMove = async (moveString) => {
			const updates = {};
			console.log(moveString);

			const newMoveKey = push(
				child(ref(rtdb), `chats/${app.currentChat.id}/gameMoves/${app.currentGame.id}/`)
			).key;

			updates[`chats/${app.currentChat.id}/gameMoves/${app.currentGame.id}/${newMoveKey}`] =
				moveString;

			updates[`chats/${app.currentChat.id}/gameState/${app.currentGame.id}/moves/`] = increment(1);

			await update(ref(rtdb), updates);
		};

		cw.updateTurn = async (turn) => {
			if (app.currentGame.id === '') return;

			console.log(turn);

			const turnRef = ref(rtdb, `chats/${app.currentChat.id}/gameInfos/${app.currentGame.id}/turn`);

			await set(turnRef, turn);
		};

		// Godot svelte stuff
		cw.gameClose = () => {
			leaveSession();
			app.resetGame();
		};

		cw.getTime = () => {
			return Date.now();
		};

		cw.GetMyGodotId = () => {
			return meshState.myGodotId;
		};

		console.log('Godot JS Bridge Outbound Functions Injected!');
	}

	// SVELTE TO GODOT
	function pushGodot(functionName, data) {
		const jsonString = JSON.stringify(data);
		if (iframeRef && iframeRef.contentWindow && iframeRef.contentWindow.sendToGodot)
			iframeRef.contentWindow.sendToGodot(functionName, jsonString);
	}

	// GODOT TO SVELTE
	function pullGodot(event) {
		const message = event.data.message;
		const payload = event.data.data;

		if (!message || !payload) return;

		// FIX this ngl.
		switch (message) {
			case 'upload':
				saveGame(payload);
				break;
			case 'batch_update':
				saveGameState(payload);
				break;
			case 'send_game':
				sendGame(payload);
				break;
		}
	}

	function leaveSession() {
		if (meshState.myGodotId === null) return;

		const sessionRef = ref(
			rtdb,
			`chats/${app.currentChat.id}/gameState/${app.currentGame.id}/active_players/${meshState.myGodotId}`
		);

		remove(sessionRef);
		onDisconnect(sessionRef).cancel();

		if (gameMovesUnsub) gameMovesUnsub();

		leaveMeshSession();
		meshState.myGodotId = null;
	}

	async function sendGame(data) {
		const gameKey = push(child(ref(rtdb), `chats/${app.currentChat.id}/gameInfos/`)).key;
		const updates = {};

		updates[`chats/${app.currentChat.id}/gameInfos/${gameKey}`] = {
			...data.gameInfo,
			timestamp: Date.now()
		};

		updates[`chats/${app.currentChat.id}/gameState/${gameKey}`] = data.gameData;

		game.resetRequest();
		await update(ref(rtdb), updates);
	}

	// SVELTE to FIREBASE
	async function saveGame(data) {
		let dataToSave = { ...data };
		dataToSave.timestamp = Date.now();

		try {
			const gameRef = ref(rtdb, `chats/${app.currentChat.id}/games/${dataToSave.id}`);
			await update(gameRef, dataToSave);
		} catch (error) {
			console.error('Failed to update game:', error);
		}
	}

	async function saveGameState(payload) {
		const updates = {};
		const basePath = `chats/${app.currentChat.id}/games/${app.currentGame.id}/gameState`;

		for (const [category, data] of Object.entries(payload)) {
			if (typeof data === 'object' && data !== null && !Array.isArray(data)) {
				for (const [key, innerValue] of Object.entries(data)) {
					// Path: .../gameState/positions/u1
					updates[`${basePath}/${category}/${key}`] = innerValue;
				}
			} else {
				// It's a global variable or simple array
				updates[`${basePath}/${category}`] = data;
			}
		}

		try {
			await update(ref(rtdb), updates);
		} catch (error) {
			console.error('Failed to update game:', error);
		}
	}

	onDestroy(() => {
		leaveSession();
	});

	import { createEventDispatcher, onDestroy, onMount } from 'svelte';
	import { fade } from 'svelte/transition';

	const dispatch = createEventDispatcher();
</script>

<svelte:window on:message={pullGodot} />

<div
	class="absolute grid grid-cols-1 items-center border-none overflow-hidden
	[scrollbar-width:none] [&::-webkit-scrollbar]:hidden box-border {isGameOpen
		? 'z-[2] pointer-events-auto'
		: 'z-0 pointer-events-none'}"
	style="
    left: {rect.x}px;
    top: {rect.y}px;
    width: {rect.w}px;
    height: {rect.h}px;
    opacity: {rect.o};
    border-radius: {rect.r}px;
"
>
	{#if gameLoading}
		<div
			out:fade={{ delay: 100, duration: 200 }}
			class="col-start-1 row-start-1 border-none w-full h-full z-10 bg-[#131313] flex items-center justify-center text-white text-xl font-bold"
		>
			Loading...
		</div>
	{/if}

	<iframe
		bind:this={iframeRef}
		id="godot-iframe"
		class="col-start-1 row-start-1 border-none w-full h-full"
		src="/godot-build/index.html"
		title="Godot Game"
		onload={handleIframeLoad}
	>
	</iframe>
	<div
		class="col-start-1 z-10 row-start-1 flex absolute flex-col justify-self-end justify-between h-[calc(100dvh-72px)] m-[36px]"
	>
		<button
			title="Close Game"
			class="[z-index:inherit] box-border rounded-full p-0 w-[36px] min-h-[42px]
			h-[42px] border-none cursor-pointer bg-transparent grid place-items-center"
			onclick={() => {
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
	</div>
</div>
