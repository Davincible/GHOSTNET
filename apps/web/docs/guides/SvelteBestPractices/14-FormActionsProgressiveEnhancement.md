# 14. Form Actions & Progressive Enhancement

## Basic Form Action

```typescript
// src/routes/contact/+page.server.ts
import type { Actions } from './$types';
import { fail, redirect } from '@sveltejs/kit';

export const actions: Actions = {
	default: async ({ request, locals }) => {
		const data = await request.formData();

		const email = data.get('email')?.toString();
		const message = data.get('message')?.toString();

		// Validation
		if (!email || !email.includes('@')) {
			return fail(400, {
				email,
				message,
				errors: { email: 'Valid email required' },
			});
		}

		if (!message || message.length < 10) {
			return fail(400, {
				email,
				message,
				errors: { message: 'Message must be at least 10 characters' },
			});
		}

		// Save to database
		try {
			await db.messages.create({ email, message });
		} catch (e) {
			return fail(500, {
				email,
				message,
				error: 'Failed to save message',
			});
		}

		redirect(303, '/contact/success');
	},
};
```

```svelte
<!-- +page.svelte -->
<script>
	import { enhance } from '$app/forms';

	let { form } = $props();
</script>

<form method="POST" use:enhance>
	<label>
		Email
		<input type="email" name="email" value={form?.email ?? ''} />
		{#if form?.errors?.email}
			<span class="error">{form.errors.email}</span>
		{/if}
	</label>

	<label>
		Message
		<textarea name="message">{form?.message ?? ''}</textarea>
		{#if form?.errors?.message}
			<span class="error">{form.errors.message}</span>
		{/if}
	</label>

	{#if form?.error}
		<p class="error">{form.error}</p>
	{/if}

	<button type="submit">Send</button>
</form>
```

## Named Actions

```typescript
// +page.server.ts
export const actions: Actions = {
	create: async ({ request }) => {
		const data = await request.formData();
		// Create logic
	},

	update: async ({ request }) => {
		const data = await request.formData();
		const id = data.get('id');
		// Update logic
	},

	delete: async ({ request }) => {
		const data = await request.formData();
		const id = data.get('id');
		// Delete logic
	},
};
```

```svelte
<!-- Different forms for different actions -->
<form method="POST" action="?/create" use:enhance>
	<input name="name" />
	<button>Create</button>
</form>

<form method="POST" action="?/update" use:enhance>
	<input type="hidden" name="id" value={item.id} />
	<input name="name" value={item.name} />
	<button>Update</button>
</form>

<form method="POST" action="?/delete" use:enhance>
	<input type="hidden" name="id" value={item.id} />
	<button>Delete</button>
</form>
```

## Custom enhance Handler

```svelte
<script lang="ts">
	import { enhance } from '$app/forms';
	import type { SubmitFunction } from '@sveltejs/kit';

	let submitting = $state(false);
	let message = $state('');

	const handleSubmit: SubmitFunction = ({ formData, cancel }) => {
		submitting = true;
		message = '';

		// Client-side validation
		const email = formData.get('email');
		if (!email || !email.toString().includes('@')) {
			message = 'Please enter a valid email';
			submitting = false;
			cancel();
			return;
		}

		// Return callback for response handling
		return async ({ result, update }) => {
			submitting = false;

			if (result.type === 'success') {
				message = 'Saved successfully!';
				// Reset form
				await update({ reset: true });
			} else if (result.type === 'failure') {
				message = 'Please fix the errors';
				await update();
			} else if (result.type === 'error') {
				message = 'An error occurred';
			}
		};
	};
</script>

<form method="POST" use:enhance={handleSubmit}>
	<input name="email" disabled={submitting} />
	<button disabled={submitting}>
		{submitting ? 'Saving...' : 'Save'}
	</button>
	{#if message}
		<p>{message}</p>
	{/if}
</form>
```

## Form with Zod Validation

```typescript
// +page.server.ts
import { z } from 'zod';
import { fail } from '@sveltejs/kit';

const contactSchema = z.object({
	name: z.string().min(2, 'Name must be at least 2 characters'),
	email: z.string().email('Invalid email address'),
	message: z.string().min(10, 'Message must be at least 10 characters'),
});

export const actions: Actions = {
	default: async ({ request }) => {
		const formData = await request.formData();
		const data = Object.fromEntries(formData);

		const result = contactSchema.safeParse(data);

		if (!result.success) {
			const errors = result.error.flatten().fieldErrors;
			return fail(400, { data, errors });
		}

		// Process valid data
		await saveContact(result.data);

		return { success: true };
	},
};
```

---

**Next:** [15. Remote Functions](./15-RemoteFunctions.md)
