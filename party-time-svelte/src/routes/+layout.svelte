<script>
	import favicon from '$lib/assets/favicon.svg';
	import { Toaster, toast } from 'svelte-sonner';
	import { onMount } from 'svelte';
	import { auth, db, rtdb } from '$lib/firebase';
	import { onAuthStateChanged } from 'firebase/auth';
	import { addDoc, collection, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';
	import { userStore } from '$lib/userData';
	import { goto } from '$app/navigation';
	import '../app.css';

	onMount(() => {
		const unsubscribe = onAuthStateChanged(auth, async (user) => {
			if (user) {
				const userDocRef = doc(db, 'users', user.uid);
				const userSnapshot = await getDoc(userDocRef);

				if (userSnapshot.exists()) {
					// Existing User: Update the store
					$userStore = {
						uid: user.uid,
						...userSnapshot.data()
					};
				} else {
					const newUserProfile = {
						username: user.email.split('@')[0],
						lastCheckedRequests: 0.0,
						active: true
					};
					await setDoc(userDocRef, newUserProfile);

					$userStore = {
						uid: user.uid,
						...newUserProfile
					};
				}

				goto('/chat');
			} else {
			}
		});
		return () => unsubscribe();
	});

	let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

{@render children()}
<Toaster richColors/>

<style>
	:global(html),
	:global(body) {
		overflow: hidden;
		font-family: 'Funnel Display', sans-serif;
	}
</style>
