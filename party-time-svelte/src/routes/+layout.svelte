<script>
	import favicon from '$lib/assets/favicon.svg';

	import { onMount } from 'svelte';
	import { auth, db, rtdb } from '$lib/firebase';
	import { onAuthStateChanged } from 'firebase/auth';
	import { collection, doc, getDoc, getDocs } from 'firebase/firestore';
	import { userStore } from '$lib/userData';
	import { goto } from '$app/navigation';

	onMount(() => {
		const unsubscribe = onAuthStateChanged(auth, async (user) => {
			if (user) {
				// User is logged in to Firebase Auth. Fetch their Firestore profile.
				const userDocRef = doc(db, 'users', user.uid);
				const userSnapshot = await getDoc(userDocRef);

				if (userSnapshot.exists()) {
					$userStore = {
						uid: user.uid,
						...userSnapshot.data()
					};

					goto('/chat');
				} else {
					// this new user...
				}
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

<style>
	:global(html),
	:global(body) {
		overflow: hidden;
		font-family: 'Funnel Display', sans-serif;
	}
</style>
