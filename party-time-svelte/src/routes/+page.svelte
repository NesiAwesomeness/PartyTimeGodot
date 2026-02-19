<script>
	import { auth } from '$lib/firebase';
	import { signInWithEmailAndPassword, createUserWithEmailAndPassword } from 'firebase/auth';
	import { goto } from '$app/navigation';
	import { userStore } from '$lib/userData';
	import { playgrounds, currentChat } from '$lib/appData';

	let username;
	let password;
	let isLoading = false;

	function handleLogin(event) {
		isLoading = true;

		event.preventDefault();
		signInWithEmailAndPassword(auth, `${username}@partytime.test`, password)
			.then((userCredential) => {})
			.catch((error) => {
				const errorCode = error.code;
				const errorMessage = error.message;
			})
			.finally(() => {
				isLoading = false;
			});
	}

	function haldleRegister(event) {
		isLoading = true;

		event.preventDefault();
		createUserWithEmailAndPassword(auth, `${username}@partytime.test`, password)
			.then((userCredential) => {})
			.catch((error) => {
				const errorCode = error.code;
				const errorMessage = error.message;
			})
			.finally(() => {
				isLoading = false;
			});
	}
</script>

<div class="account-auth">
	<div class="account-auth-spacer"></div>
	<div class="account-auth-form">
		<div>
			<div class="auth-title">
				<h3>Sign In or Sign Up</h3>
				<p>Play text message games with your friends</p>
			</div>
			<form class="auth-form" onsubmit={handleLogin}>
				<input
					type="text"
					name="username"
					placeholder="Username"
					bind:value={username}
					autocomplete="username"
					required
				/>
				<input
					type="password"
					name="password"
					placeholder="Password"
					bind:value={password}
					autocomplete="current-password"
					required
				/>
				<div class="button-group">
					<button type="submit" onclick={handleLogin} disabled={isLoading}>
						{isLoading ? 'Wait...' : 'Sign In'}</button
					>
					<button type="button" onclick={haldleRegister} disabled={isLoading}> Register </button>
				</div>
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
</style>
