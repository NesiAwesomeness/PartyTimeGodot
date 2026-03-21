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

	const validateInputs = () => {
		if (!userName || !password) {
			toast.error('Please fill in all fields.');
			return false;
		}
		if (/\s/.test(userName)) {
			toast.error('Username cannot contain spaces.');
			return false;
		}
		if (password.length < 6) {
			toast.error('Password must be at least 8 characters long.');
			return false;
		}
		return true;
	};

	function handleLogin(event) {
		if (!validateInputs()) return;
		isLoading = true;

		event.preventDefault();
		signInWithEmailAndPassword(auth, `${userName.toLowerCase()}@partytime.test`, password)
			.then(() => {
				toast.success(`Welcome @${userName.toLowerCase()}!`);
			})
			.catch((error) => {
				switch (error.code) {
					case 'auth/invalid-credential':
						toast.error('Wrong username or password :(');
						break;
					case 'auth/user-disabled':
						toast.error('This account has been disabled.');
						break;
					case 'auth/too-many-requests':
						toast.error('Too many failed attempts. Please try again later.');
						break;
					case 'auth/network-request-failed':
						toast.error('Network error. Please check your connection.');
						break;
					default:
						toast.error('An unexpected error occurred while logging in.');
						console.error('Login Error:', error); // Good to log unexpected errors for debugging
				}
			})
			.finally(() => {
				isLoading = false;
			});
	}

	function handleRegister(event) {
		if (!validateInputs()) return;
		isLoading = true;

		event.preventDefault();
		createUserWithEmailAndPassword(auth, `${userName.toLowerCase()}@partytime.test`, password)
			.then(() => {
				toast.success(`Welcome @${userName.toLowerCase()}!`);
			})
			.catch((error) => {
				switch (error.code) {
					case 'auth/email-already-in-use':
						// We translate "email" to "username" here since that's how your app is structured
						toast.error('That username is already taken!');
						break;
					case 'auth/weak-password':
						toast.error('Your password is too weak. Try adding numbers or symbols.');
						break;
					case 'auth/network-request-failed':
						toast.error('Network error. Please check your connection.');
						break;
					case 'auth/invalid-email':
						toast.error('Invalid username format.');
						break;
					default:
						toast.error('An unexpected error occurred during registration.');
						console.error('Register Error:', error);
				}
			})
			.finally(() => {
				isLoading = false;
			});
	}
</script>

<div class="grid grid-flow-col grid-cols-2 portrait:grid-cols-1 w-screen h-[100dvh] bg-[#0f0f0f]">
	<div class="bg-[#212121] m-4 rounded-lg portrait:hidden">
		<h2
			class="text-[5em] h-full m-0 w-full text-white flex justify-center items-center text-center leading-none"
		>
			PARTY TIME!
		</h2>
	</div>

	<div class="grid justify-items-center items-center text-white">
		<div>
			<div class="my-4 text-xs grid gap-2">
				{#if isSignin}
					<h3 class="!text-3xl m-0">Sign In</h3>
				{:else}
					<h3 class="!text-3xl m-0">Sign Up</h3>
				{/if}
				<p class="text-base m-0 text-white/[0.57]">Play text message games with your friends</p>
			</div>

			<form
				novalidate
				class="grid grid-flow-row gap-4"
				onsubmit={isSignin ? handleLogin : handleRegister}
			>
				<input
					type="text"
					name="username"
					placeholder="Username"
					bind:value={userName}
					autocomplete="username"
					pattern="^\S+$"
					title="Username cannot contain spaces"
					class="box-border w-full bg-[#2a2a2a] text-white rounded-full py-3 px-6 text-base font-inherit focus:outline-none"
					required
				/>
				<div class="relative">
					<input
						type={passwordSeen ? 'text' : 'password'}
						name="password"
						placeholder="Password"
						bind:value={password}
						autocomplete="current-password"
						minlength="8"
						title="Password must be at least 8 characters long"
						class="box-border w-full bg-[#2a2a2a] text-white rounded-full py-3 px-6 text-base font-inherit focus:outline-none"
						required
					/>
					{#if passwordSeen}
						<EyeOpen
							onClick={() => {
								passwordSeen = false;
							}}
							class="absolute top-1/2 -translate-y-1/2 right-4 w-[17px] h-[17px] cursor-pointer"
						/>
					{:else}
						<EyeClosed
							onClick={() => {
								passwordSeen = true;
							}}
							class="absolute top-1/2 -translate-y-1/2 right-4 w-[17px] h-[17px] cursor-pointer"
						/>
					{/if}
				</div>

				<div class="grid grid-flow-col portrait:grid-flow-row gap-4">
					{#if isSignin}
						<button
							type="submit"
							disabled={isLoading}
							class="cursor-pointer box-border w-full bg-[#2a2a2a] text-white rounded-full text-center py-3 px-6 text-base font-inherit font-semibold focus:outline-none disabled:opacity-50"
						>
							{#if isLoading}
								<div class="flex justify-center items-center">
									<Loader size={20} />
								</div>
							{:else}
								Sign In
							{/if}
						</button>
					{:else}
						<button
							type="submit"
							disabled={isLoading}
							class="cursor-pointer box-border w-full bg-[#2a2a2a] text-white rounded-full text-center py-3 px-6 text-base font-inherit font-semibold focus:outline-none disabled:opacity-50"
						>
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
								isSignin = false;
							}}
							class="underline cursor-pointer inline bg-transparent border-none p-0 text-inherit font-inherit"
							>Create an account</button
						>
					{:else}
						Have an account? <button
							onclick={(e) => {
								e.preventDefault();
								isSignin = true;
							}}
							class="underline cursor-pointer inline bg-transparent border-none p-0 text-inherit font-inherit"
							>Sign in</button
						>
					{/if}
				</p>
			</form>
		</div>
	</div>
</div>
