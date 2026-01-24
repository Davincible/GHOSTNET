<script lang="ts">
	/**
	 * StreakCalendar
	 * ==============
	 * Monthly calendar view showing completed mission days.
	 * Displays current month with visual indicators for:
	 * - Completed days (checkmark)
	 * - Today (highlighted)
	 * - Future days (dimmed)
	 * - Missed days (X mark)
	 */

	interface Props {
		/** Set of completed day numbers (UTC day since epoch) */
		completedDays: Set<number>;
		/** Current UTC day number */
		currentDay: number;
		/** Streak start day (for highlighting streak period) */
		streakStartDay?: number;
	}

	let { completedDays, currentDay, streakStartDay }: Props = $props();

	// Get current date info
	let today = $derived(new Date(currentDay * 86400000));
	let currentMonth = $derived(today.getUTCMonth());
	let currentYear = $derived(today.getUTCFullYear());

	// Month navigation
	let viewMonth = $state(new Date().getUTCMonth());
	let viewYear = $state(new Date().getUTCFullYear());

	// Month names
	const MONTHS = [
		'JANUARY',
		'FEBRUARY',
		'MARCH',
		'APRIL',
		'MAY',
		'JUNE',
		'JULY',
		'AUGUST',
		'SEPTEMBER',
		'OCTOBER',
		'NOVEMBER',
		'DECEMBER',
	];

	const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

	// Calculate calendar days for the view month
	let calendarDays = $derived.by(() => {
		const firstOfMonth = new Date(Date.UTC(viewYear, viewMonth, 1));
		const lastOfMonth = new Date(Date.UTC(viewYear, viewMonth + 1, 0));

		// Get day of week (0 = Sunday, we want Monday = 0)
		let startDow = firstOfMonth.getUTCDay();
		startDow = startDow === 0 ? 6 : startDow - 1; // Convert to Monday-based

		const daysInMonth = lastOfMonth.getUTCDate();
		const weeks: Array<Array<CalendarDay | null>> = [];

		let week: Array<CalendarDay | null> = [];

		// Add empty cells for days before the 1st
		for (let i = 0; i < startDow; i++) {
			week.push(null);
		}

		// Add each day of the month
		for (let day = 1; day <= daysInMonth; day++) {
			const date = new Date(Date.UTC(viewYear, viewMonth, day));
			const utcDay = Math.floor(date.getTime() / 86400000);

			const isToday = utcDay === currentDay;
			const isFuture = utcDay > currentDay;
			const isCompleted = completedDays.has(utcDay);
			const isInStreak = streakStartDay ? utcDay >= streakStartDay && utcDay <= currentDay : false;

			// A day is "missed" if it's in the past, not completed, and after streak started
			const isMissed =
				!isFuture && !isCompleted && streakStartDay ? utcDay > streakStartDay : false;

			week.push({
				day,
				utcDay,
				isToday,
				isFuture,
				isCompleted,
				isInStreak,
				isMissed,
			});

			if (week.length === 7) {
				weeks.push(week);
				week = [];
			}
		}

		// Fill last week with empty cells
		if (week.length > 0) {
			while (week.length < 7) {
				week.push(null);
			}
			weeks.push(week);
		}

		return weeks;
	});

	interface CalendarDay {
		day: number;
		utcDay: number;
		isToday: boolean;
		isFuture: boolean;
		isCompleted: boolean;
		isInStreak: boolean;
		isMissed: boolean;
	}

	// Navigate months
	function prevMonth() {
		if (viewMonth === 0) {
			viewMonth = 11;
			viewYear--;
		} else {
			viewMonth--;
		}
	}

	function nextMonth() {
		// Don't allow navigating past current month
		if (viewYear === currentYear && viewMonth === currentMonth) return;

		if (viewMonth === 11) {
			viewMonth = 0;
			viewYear++;
		} else {
			viewMonth++;
		}
	}

	// Check if we can navigate forward
	let canGoNext = $derived(!(viewYear === currentYear && viewMonth === currentMonth));

	// Count stats for the month
	let monthStats = $derived.by(() => {
		let completed = 0;
		let total = 0;

		for (const week of calendarDays) {
			for (const day of week) {
				if (day && !day.isFuture) {
					total++;
					if (day.isCompleted) completed++;
				}
			}
		}

		return { completed, total };
	});
</script>

<div class="streak-calendar">
	<header class="calendar-header">
		<button class="nav-btn" onclick={prevMonth} aria-label="Previous month">&lt;</button>
		<span class="month-year">{MONTHS[viewMonth]} {viewYear}</span>
		<button class="nav-btn" onclick={nextMonth} disabled={!canGoNext} aria-label="Next month">
			&gt;
		</button>
	</header>

	<div class="calendar-grid">
		<!-- Day headers -->
		<div class="day-headers">
			{#each DAYS as day}
				<span class="day-header">{day}</span>
			{/each}
		</div>

		<!-- Calendar weeks -->
		{#each calendarDays as week}
			<div class="week-row">
				{#each week as day}
					{#if day}
						<div
							class="day-cell"
							class:today={day.isToday}
							class:future={day.isFuture}
							class:completed={day.isCompleted}
							class:missed={day.isMissed}
							class:in-streak={day.isInStreak}
						>
							<span class="day-number">{day.day}</span>
							{#if day.isCompleted}
								<span class="day-status completed-icon">✓</span>
							{:else if day.isToday}
								<span class="day-status today-icon">●</span>
							{:else if day.isMissed}
								<span class="day-status missed-icon">×</span>
							{:else if !day.isFuture}
								<span class="day-status empty-icon">○</span>
							{/if}
						</div>
					{:else}
						<div class="day-cell empty"></div>
					{/if}
				{/each}
			</div>
		{/each}
	</div>

	<footer class="calendar-footer">
		<div class="legend">
			<span class="legend-item"><span class="legend-icon completed">✓</span> Completed</span>
			<span class="legend-item"><span class="legend-icon today">●</span> Today</span>
			<span class="legend-item"><span class="legend-icon missed">×</span> Missed</span>
		</div>
		<div class="month-stats">
			{monthStats.completed}/{monthStats.total} days
		</div>
	</footer>
</div>

<style>
	.streak-calendar {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		max-width: 320px;
		width: 100%;
	}

	.calendar-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.nav-btn {
		background: transparent;
		border: 1px solid var(--color-border-default);
		color: var(--color-text-secondary);
		padding: var(--space-0-5) var(--space-1);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.nav-btn:hover:not(:disabled) {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}

	.nav-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.month-year {
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wider);
	}

	.calendar-grid {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.day-headers {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
		gap: 2px;
	}

	.day-header {
		text-align: center;
		font-size: 9px;
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wide);
		padding: var(--space-0-5) 0;
	}

	.week-row {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
		gap: 2px;
	}

	.day-cell {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1px;
		background: var(--color-bg-tertiary);
		border: 1px solid transparent;
		height: 32px;
		padding: 2px;
	}

	.day-cell.empty {
		background: transparent;
		border: none;
	}

	.day-cell.today {
		border-color: var(--color-accent);
		background: var(--color-accent-glow);
	}

	.day-cell.completed {
		background: rgba(0, 255, 136, 0.1);
		border-color: var(--color-success);
	}

	.day-cell.completed.in-streak {
		background: rgba(0, 255, 136, 0.15);
	}

	.day-cell.missed {
		background: rgba(255, 0, 0, 0.05);
	}

	.day-cell.future {
		opacity: 0.4;
	}

	.day-number {
		font-size: 10px;
		font-family: var(--font-mono);
		color: var(--color-text-secondary);
		line-height: 1;
	}

	.day-cell.today .day-number {
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	.day-cell.completed .day-number {
		color: var(--color-success);
	}

	.day-status {
		font-size: 8px;
		line-height: 1;
	}

	.completed-icon {
		color: var(--color-success);
	}

	.today-icon {
		color: var(--color-accent);
		animation: pulse 2s ease-in-out infinite;
	}

	.missed-icon {
		color: var(--color-danger);
		opacity: 0.6;
	}

	.empty-icon {
		color: var(--color-text-muted);
		opacity: 0.4;
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}

	.calendar-footer {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-top: var(--space-1);
		border-top: 1px solid var(--color-border-subtle);
		font-size: 9px;
	}

	.legend {
		display: flex;
		gap: var(--space-2);
	}

	.legend-item {
		display: flex;
		align-items: center;
		gap: 2px;
		color: var(--color-text-muted);
	}

	.legend-icon {
		font-size: 10px;
	}

	.legend-icon.completed {
		color: var(--color-success);
	}

	.legend-icon.today {
		color: var(--color-accent);
	}

	.legend-icon.missed {
		color: var(--color-danger);
	}

	.month-stats {
		font-family: var(--font-mono);
		color: var(--color-text-secondary);
	}

	/* Smaller screens */
	@media (max-width: 360px) {
		.streak-calendar {
			max-width: 280px;
		}

		.day-cell {
			height: 28px;
		}

		.day-number {
			font-size: 9px;
		}

		.day-status {
			font-size: 7px;
		}
	}
</style>
