<script>
	import { rtdb } from '$lib/firebase';
	import { currentChat, getGameState } from '$lib/appData';
	import { push, ref, update } from 'firebase/database';

	export let game = {
		name: 'Game Title',
		key: '',
		isTurnBased: true
	};

	async function newGame() {
		if ($currentChat.id === '') return;

		const chatRef = ref(rtdb, `chats/${$currentChat.id}/games`);

		game.timestamp = Date.now();
		game = { ...game, gameState: getGameState(game.key) };

		console.log(game);

		try {
			await push(chatRef, game);
		} catch (error) {}
	}
</script>

<button class="game-option" on:click={newGame}>
	<span>{game.name}</span>
	<span class="wins">
		<svg
			xmlns="http://www.w3.org/2000/svg"
			id="Layer_1"
			data-name="Layer 1"
			viewBox="0 0 24 24"
			xml:space="preserve"
			class="path"
		>
			<path
				d="m22.305,2.87l-2.281,4.622c-1.639-1.751-3.84-2.96-6.319-3.347l.945-1.915c.679-1.376,2.053-2.23,3.587-2.23h2.283c.692,0,1.324.351,1.689.939.366.588.401,1.31.095,1.931Zm-12.01,1.275l-.945-1.915c-.679-1.376-2.053-2.23-3.587-2.23h-2.26c-.692,0-1.324.351-1.689.938-.366.589-.401,1.311-.095,1.932l2.272,4.607c1.637-1.743,3.833-2.945,6.304-3.331Zm10.706,10.855c0,4.963-4.038,9-9,9S3,19.963,3,15,7.038,6,12,6s9,4.037,9,9Zm-4.843-.59c0-.306-.266-.644-.696-.644h-2.14l-.567-2.175c-.09-.345-.399-.585-.755-.591-.355.007-.665.246-.755.591l-.567,2.175h-2.14c-.43,0-.696.337-.696.644,0,.361.251.665.539.825l1.49.828-.661,1.803c-.128.349-.012.741.285.965h0c.304.229.723.226,1.023-.007l1.482-1.146,1.482,1.146c.301.232.72.235,1.023.007h0c.297-.224.413-.615.285-.965l-.661-1.803,1.49-.828c.288-.16.539-.464.539-.825Z"
			/>
		</svg> 1
	</span>
</button>

<style>
	.game-option {
		display: flex;
		flex-direction: column;
		gap: 4px;

		cursor: pointer;

		padding: 8px;
		border-radius: 12px;
		border: none;

		height: fit-content;
		color: white;

		font-weight: 600;
		font-size: 1rem;
		font-family: 'Funnel Display', sans-serif;

		background-color: rgb(158, 185, 103);
		box-shadow: inset 0 0 8px rgba(255, 255, 255, 0.25);
	}

	.wins {
		display: flex;
		gap: 4px;

		align-items: center;

		background-color: rgba(0, 0, 0, 0.151);

		padding: 2px 8px;
		border-radius: 16px;

		font-size: 0.75rem;

		width: fit-content;
	}

	.path {
		fill: rgba(255, 255, 255, 0.763);
		width: 12px;
	}
</style>
