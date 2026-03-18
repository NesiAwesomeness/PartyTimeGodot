<script>
	import { auth } from '$lib/firebase';
	import { signInWithEmailAndPassword, createUserWithEmailAndPassword } from 'firebase/auth';

	import { goto } from '$app/navigation';
	import { toast } from 'svelte-sonner';
	import { onMount } from 'svelte';

	import Loader from '$lib/interfaces/Loader.svelte';
	import Modal from '$lib/interfaces/Modal.svelte';
	import EyeOpen from '$lib/interfaces/EyeOpen.svelte';
	import EyeClosed from '$lib/interfaces/EyeClosed.svelte';

	let userName = '';
	let password;
	let isLoading = false;
	let isSignin = true;
	let passwordSeen = false;

	onMount(() => (isLoading = false));

	function handleLogin(event) {
		isLoading = true;

		event.preventDefault();
		signInWithEmailAndPassword(auth, `${userName.toLowerCase()}@partytime.test`, password)
			.then()
			.catch((error) => {
				const errorCode = error.code;
				const errorMessage = error.message;
				if (errorMessage == 'Firebase: Error (auth/invalid-credential).') {
					toast.error('Wrong Username or password :(');
				}
			})
			.finally(() => {
				toast.success(`Welcome @${userName.toLowerCase()}!`);
				isLoading = false;
			});
	}

	function handleRegister(event) {
		isLoading = true;

		event.preventDefault();
		createUserWithEmailAndPassword(auth, `${userName.toLowerCase()}@partytime.test`, password)
			.then()
			.catch((error) => {
				const errorCode = error.code;
				const errorMessage = error.message;
				toast.error(error.message);
			})
			.finally(() => {
				toast.success(`Welcome @${userName.toLowerCase()}!`);
				isLoading = false;
			});
	}
</script>

<div class="account-auth">
	<div class="account-auth-spacer">
		<h2 class="game-title">PARTY TIME!</h2>
	</div>
	<div class="account-auth-form">
		<div>
			<div class="auth-title">
				{#if isSignin}
					<h3 class="!text-3xl">Sign In</h3>
				{:else}
					<h3 class="!text-3xl">Sign Up</h3>
				{/if}
				<p class="text-base">Play text message games with your friends</p>
			</div>
			<form class="auth-form" onsubmit={handleLogin}>
				<input
					type="text"
					name="username"
					placeholder="Username"
					bind:value={userName}
					autocomplete="username"
					required
				/>
				<div class="relative">
					<input
						type={passwordSeen ? 'text' : 'password'}
						name="password"
						placeholder="Password"
						bind:value={password}
						autocomplete="current-password"
						required
					/>
					{#if passwordSeen}
						<EyeOpen
							onClick={() => {
								passwordSeen = false;
							}}
							class="absolute center-y right-4 size-[17px] cursor-pointer"
						/>
					{:else}
						<EyeClosed
							onClick={() => {
								passwordSeen = true;
							}}
							class="absolute center-y right-4 size-[17px] cursor-pointer"
						/>
					{/if}
				</div>
				<div class="button-group">
					{#if isSignin}
						<button type="submit" onclick={handleLogin} disabled={isLoading}>
							{#if isLoading}
								<div class="flex justify-center items-center">
									<Loader size={20} />
								</div>
							{:else}
								Sign In
							{/if}
						</button>
					{:else}
						<button type="button" onclick={handleRegister} disabled={isLoading}>
							{#if isLoading}
								<div class="flex justify-center items-center">
									<Loader size={20} />
								</div>
							{:else}
								Register
							{/if}
						</button>
					{/if}
				</div>

				<p class="text-sm italic text-white/50 mt-[-8px] ml-[6px]">
					{#if isSignin}
						New here? <button
							onclick={(e) => {
								e.preventDefault();
								isSignin = !isSignin;
							}}
							class="underline cursor-pointer inline">Create an account</button
						>
					{:else}
						Have an account? <button
							onclick={(e) => {
								e.preventDefault();
								isSignin = !isSignin;
							}}
							class="underline cursor-pointer inline">Sign in</button
						>
					{/if}
				</p>
			</form>
		</div>
	</div>
</div>

<style>
	.account-auth {
		display: grid;
		grid-auto-flow: column;
		grid-template-columns: 1fr 1fr;

		width: 100vw;
		height: 100vh;
		background-color: rgb(15, 15, 15);
	}

	.account-auth-spacer {
		background-color: rgb(33, 33, 33);
		margin: 16px;
		border-radius: 8px;
	}

	.account-auth-form {
		display: grid;
		justify-items: center;
		align-items: center;

		color: white;
	}

	.auth-title {
		margin: 16px 0;
		font-size: 0.75rem;
		display: grid;
		gap: 8px;
	}

	.auth-title p {
		margin: 0;
		color: rgba(255, 255, 255, 0.571);
	}

	.auth-title h3 {
		margin: 0;
		font-size: 1.5rem;
	}

	.auth-form {
		display: grid;
		grid-auto-flow: row;
		gap: 16px;
	}

	.auth-form input {
		all: unset;

		box-sizing: border-box;
		width: 100%;

		background-color: #2a2a2a;
		color: white;

		border-radius: 9999px;

		padding: 12px 24px;
		font-size: 1rem;

		font-family: inherit;
	}

	.button-group {
		display: grid;
		grid-auto-flow: column;
		gap: 16px;
	}

	.button-group button {
		all: unset;
		cursor: pointer;

		box-sizing: border-box;
		width: 100%;

		background-color: #2a2a2a;
		color: white;

		border-radius: 9999px;
		text-align: center;

		padding: 12px 24px;
		font-size: 1rem;
		font-family: inherit;
		font-weight: 600;
	}

	@media (orientation: portrait) {
		.account-auth {
			grid-template-columns: 1fr; /* Forces it into a single column */
		}

		.account-auth-spacer {
			display: none;
		}

		.button-group {
			grid-auto-flow: row;
		}
	}

	.game-title {
		font-size: 5em;
		height: 100%;
		margin: 0;

		width: 100%;
		color: white;
		/* margin-inline: auto; */
		display: flex;
		justify-content: center;
		align-items: center;
		text-align: center;
		line-height: 100%;
	}
</style>
