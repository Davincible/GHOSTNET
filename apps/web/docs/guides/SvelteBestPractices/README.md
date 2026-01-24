# Svelte 5 Best Practices Guide

**Svelte Version:** 5.x | **SvelteKit Version:** 2.x | **Last Updated:** January 2026

---

## What Are You Trying To Do?

### I need to...

| Task                                                            | Read                                                                                   |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **Understand Svelte 5 runes** (`$state`, `$derived`, `$effect`) | [01-ReactivityFundamentals](./01-ReactivityFundamentals.md)                            |
| **Make a variable reactive**                                    | [02-StateInDepth](./02-StateInDepth.md)                                                |
| **Compute a value from other values**                           | [03-DerivedMastery](./03-DerivedMastery.md)                                            |
| **Run code when values change** (side effects)                  | [04-EffectWhenAndHow](./04-EffectWhenAndHow.md)                                        |
| **Accept props in a component**                                 | [05-PropsAndComponentAPI](./05-PropsAndComponentAPI.md)                                |
| **Pass content/templates to a component** (slots → snippets)    | [06-SnippetsTheNewSlots](./06-SnippetsTheNewSlots.md)                                  |
| **Handle click/input/submit events**                            | [07-EventHandling](./07-EventHandling.md)                                              |
| **Run code on mount/unmount**                                   | [08-LifecycleInSvelte5](./08-LifecycleInSvelte5.md)                                    |
| **Share state across components** (global store)                | [09-StateManagementPatterns](./09-StateManagementPatterns.md)                          |
| **Share state down a component tree** (without prop drilling)   | [10-ContextAPI](./10-ContextAPI.md)                                                    |
| **Use reactive Set/Map/URL/Date**                               | [11-ReactiveCollections](./11-ReactiveCollections.md)                                  |
| **Add TypeScript to components**                                | [12-TypeScriptIntegration](./12-TypeScriptIntegration.md)                              |
| **Load data for a page** (SvelteKit)                            | [13-SvelteKitDataLoading](./13-SvelteKitDataLoading.md)                                |
| **Handle form submissions** (SvelteKit)                         | [14-FormActionsProgressiveEnhancement](./14-FormActionsProgressiveEnhancement.md)      |
| **Call server functions from client** (RPC-style)               | [15-RemoteFunctions](./15-RemoteFunctions.md)                                          |
| **Avoid SSR/hydration issues**                                  | [16-SSRAndHydration](./16-SSRAndHydration.md)                                          |
| **Use `await` directly in components**                          | [17-AsyncSSR](./17-AsyncSSR.md)                                                        |
| **Optimize performance**                                        | [18-PerformancePatterns](./18-PerformancePatterns.md)                                  |
| **Build compound/polymorphic components**                       | [19-ComponentComposition](./19-ComponentComposition.md)                                |
| **Add animations/transitions**                                  | [20-AnimationsAndTransitions](./20-AnimationsAndTransitions.md)                        |
| **Run code when element mounts** (actions → attachments)        | [21-Attachments](./21-Attachments.md)                                                  |
| **Migrate from Svelte 4**                                       | [22-MigrationFromSvelte4](./22-MigrationFromSvelte4.md)                                |
| **Avoid common mistakes**                                       | [23-AntipatternsReference](./23-AntipatternsReference.md)                              |
| **Write tests for Svelte 5 code**                               | [26-TestingSetup](./26-TestingSetup.md), [27-TestingPatterns](./27-TestingPatterns.md) |
| **Fix "$state is not defined" in tests**                        | [26-TestingSetup](./26-TestingSetup.md#critical-file-naming-convention)                |
| **Test `$effect` with flushSync**                               | [27-TestingPatterns](./27-TestingPatterns.md#testing-effect)                           |
| **Look up syntax quickly**                                      | [25-QuickReferenceCheatsheet](./25-QuickReferenceCheatsheet.md)                        |
| **Connect to smart contracts** (Web3)                           | [28-Web3Integration](./28-Web3Integration.md)                                          |

---

## Common Questions

### Reactivity

| Question                                                   | Answer In                                                                        |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------- |
| "What's the difference between `$state` and `$state.raw`?" | [02-StateInDepth](./02-StateInDepth.md#stateraw---opting-out-of-deep-reactivity) |
| "When do I use `$derived` vs `$derived.by`?"               | [03-DerivedMastery](./03-DerivedMastery.md#derivedby-for-complex-logic)          |
| "Can I use `async/await` in `$derived`?"                   | [03-DerivedMastery](./03-DerivedMastery.md#async-in-derived-limitations)         |
| "When should I use `$effect` vs `$derived`?"               | [04-EffectWhenAndHow](./04-EffectWhenAndHow.md#the-golden-rule)                  |
| "How do I avoid infinite loops in effects?"                | [04-EffectWhenAndHow](./04-EffectWhenAndHow.md#avoiding-infinite-loops)          |

### Components

| Question                                           | Answer In                                                                          |
| -------------------------------------------------- | ---------------------------------------------------------------------------------- |
| "How do I make a prop bindable (two-way)?"         | [05-PropsAndComponentAPI](./05-PropsAndComponentAPI.md#bindable---two-way-binding) |
| "How do I pass all remaining props to an element?" | [05-PropsAndComponentAPI](./05-PropsAndComponentAPI.md#rest-props-spread)          |
| "What replaced slots in Svelte 5?"                 | [06-SnippetsTheNewSlots](./06-SnippetsTheNewSlots.md)                              |
| "How do I emit custom events to parent?"           | [07-EventHandling](./07-EventHandling.md#custom-events-via-callbacks)              |
| "What happened to `on:click`?"                     | [07-EventHandling](./07-EventHandling.md#new-syntax-on-prefix)                     |

### State Management

| Question                                      | Answer In                                                                                        |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| "How do I create a global store?"             | [09-StateManagementPatterns](./09-StateManagementPatterns.md#pattern-2-object-store-recommended) |
| "How do I share state without passing props?" | [10-ContextAPI](./10-ContextAPI.md)                                                              |
| "Is global state safe with SSR?"              | [09-StateManagementPatterns](./09-StateManagementPatterns.md#ssr-warning-global-state)           |

### SvelteKit

| Question                                                          | Answer In                                                                                                  |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| "How do I access the current URL/page data?"                      | [13-SvelteKitDataLoading](./13-SvelteKitDataLoading.md#appstate-sveltekit-212)                             |
| "What's the difference between `+page.ts` and `+page.server.ts`?" | [13-SvelteKitDataLoading](./13-SvelteKitDataLoading.md)                                                    |
| "How do I handle form validation?"                                | [14-FormActionsProgressiveEnhancement](./14-FormActionsProgressiveEnhancement.md#form-with-zod-validation) |
| "What are remote functions?"                                      | [15-RemoteFunctions](./15-RemoteFunctions.md)                                                              |

### Animations

| Question                                    | Answer In                                                                                      |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| "How do I animate a value smoothly?"        | [20-AnimationsAndTransitions](./20-AnimationsAndTransitions.md#spring-and-tween-svelte-58)     |
| "What's the new Spring/Tween API?"          | [20-AnimationsAndTransitions](./20-AnimationsAndTransitions.md#spring-physics-based-animation) |
| "What does `transition:slide\|local` mean?" | [20-AnimationsAndTransitions](./20-AnimationsAndTransitions.md#the-local-modifier)             |

### Testing

| Question                                  | Answer In                                                                        |
| ----------------------------------------- | -------------------------------------------------------------------------------- |
| "Why don't runes work in my tests?"       | [26-TestingSetup](./26-TestingSetup.md#the-problem-why-runes-dont-work-in-tests) |
| "Should I use jsdom or browser mode?"     | [26-TestingSetup](./26-TestingSetup.md#testing-approaches-overview)              |
| "How do I test `$effect`?"                | [27-TestingPatterns](./27-TestingPatterns.md#testing-effect)                     |
| "How do I test components with snippets?" | [27-TestingPatterns](./27-TestingPatterns.md#component-with-snippets)            |
| "How do I test stores/context?"           | [27-TestingPatterns](./27-TestingPatterns.md#testing-stores-and-context)         |

### Migration & Troubleshooting

| Question                                      | Answer In                                                                                                     |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| "How do I convert Svelte 4 code to Svelte 5?" | [22-MigrationFromSvelte4](./22-MigrationFromSvelte4.md)                                                       |
| "Why is my component so slow?"                | [23-AntipatternsReference](./23-AntipatternsReference.md#converting-derived-to-getter-functions-catastrophic) |
| "What replaced `$app/stores`?"                | [13-SvelteKitDataLoading](./13-SvelteKitDataLoading.md#appstate-sveltekit-212)                                |
| "What replaced `use:action`?"                 | [21-Attachments](./21-Attachments.md)                                                                         |

---

## Quick Start Paths

### New to Svelte 5?

1. [01-ReactivityFundamentals](./01-ReactivityFundamentals.md) — The runes paradigm
2. [02-StateInDepth](./02-StateInDepth.md) — Reactive state
3. [03-DerivedMastery](./03-DerivedMastery.md) — Computed values
4. [25-QuickReferenceCheatsheet](./25-QuickReferenceCheatsheet.md) — Bookmark this

### Migrating from Svelte 4?

1. [22-MigrationFromSvelte4](./22-MigrationFromSvelte4.md) — Syntax changes
2. [23-AntipatternsReference](./23-AntipatternsReference.md) — Don't make these mistakes
3. [06-SnippetsTheNewSlots](./06-SnippetsTheNewSlots.md) — Slots are now snippets

### Building a SvelteKit app?

1. [13-SvelteKitDataLoading](./13-SvelteKitDataLoading.md) — Load functions
2. [14-FormActionsProgressiveEnhancement](./14-FormActionsProgressiveEnhancement.md) — Forms
3. [16-SSRAndHydration](./16-SSRAndHydration.md) — SSR patterns

### Building a Web3 dApp?

1. [28-Web3Integration](./28-Web3Integration.md) — viem/wagmi setup, wallet stores, contract interactions

### Writing tests?

1. [26-TestingSetup](./26-TestingSetup.md) — Why runes fail in tests, file naming
2. [27-TestingPatterns](./27-TestingPatterns.md) — Testing `$state`, `$effect`, components

---

## Full Table of Contents

| #   | Section                                                      | When to Read                                         |
| --- | ------------------------------------------------------------ | ---------------------------------------------------- |
| 01  | [Reactivity Fundamentals](./01-ReactivityFundamentals.md)    | Understanding `$state`, `$derived`, `$effect` basics |
| 02  | [$state In Depth](./02-StateInDepth.md)                      | Deep reactivity, `$state.raw`, `$state.snapshot`     |
| 03  | [$derived Mastery](./03-DerivedMastery.md)                   | Computed values, filtering, async patterns           |
| 04  | [$effect: When & How](./04-EffectWhenAndHow.md)              | Side effects, cleanup, DOM manipulation              |
| 05  | [$props & Component API](./05-PropsAndComponentAPI.md)       | Props, `$bindable`, rest props, TypeScript           |
| 06  | [Snippets: The New Slots](./06-SnippetsTheNewSlots.md)       | Passing templates, render props                      |
| 07  | [Event Handling](./07-EventHandling.md)                      | `onclick`, callbacks, event types                    |
| 08  | [Lifecycle in Svelte 5](./08-LifecycleInSvelte5.md)          | Mount, unmount, `tick()`                             |
| 09  | [State Management Patterns](./09-StateManagementPatterns.md) | Stores, factories, class-based state                 |
| 10  | [Context API](./10-ContextAPI.md)                            | `setContext`, `getContext`, type-safe context        |
| 11  | [Reactive Collections](./11-ReactiveCollections.md)          | `SvelteSet`, `SvelteMap`, `SvelteURL`                |
| 12  | [TypeScript Integration](./12-TypeScriptIntegration.md)      | Props typing, generics, event types                  |
| 13  | [SvelteKit Data Loading](./13-SvelteKitDataLoading.md)       | Load functions, `$app/state`, streaming              |
| 14  | [Form Actions](./14-FormActionsProgressiveEnhancement.md)    | `use:enhance`, validation, named actions             |
| 15  | [Remote Functions](./15-RemoteFunctions.md)                  | `query()`, `action()`, `form()` — _Experimental_     |
| 16  | [SSR & Hydration](./16-SSRAndHydration.md)                   | SSR safety, hydration mismatches, `browser`          |
| 17  | [Async SSR](./17-AsyncSSR.md)                                | Top-level `await` in components — _Experimental_     |
| 18  | [Performance Patterns](./18-PerformancePatterns.md)          | Keys, lazy loading, debouncing                       |
| 19  | [Component Composition](./19-ComponentComposition.md)        | Compound, polymorphic, HOC patterns                  |
| 20  | [Animations & Transitions](./20-AnimationsAndTransitions.md) | `Spring`, `Tween`, transitions, `\|local`            |
| 21  | [Attachments](./21-Attachments.md)                           | `{@attach}`, replacing actions                       |
| 22  | [Migration from Svelte 4](./22-MigrationFromSvelte4.md)      | Syntax conversion, gotchas                           |
| 23  | [Antipatterns Reference](./23-AntipatternsReference.md)      | Common mistakes and fixes                            |
| 24  | [Tips & Tricks](./24-TipsAndTricks.md)                       | Shortcuts, patterns, utilities                       |
| 25  | [Quick Reference](./25-QuickReferenceCheatsheet.md)          | Imports, syntax, sv CLI                              |
| 26  | [Testing Setup](./26-TestingSetup.md)                        | Vitest config, file naming, CI/CD                    |
| 27  | [Testing Patterns](./27-TestingPatterns.md)                  | Testing runes, components, stores                    |
| 28  | [Web3 Integration](./28-Web3Integration.md)                  | viem, wagmi, wallet connections, contracts           |

---

## Version Compatibility

| Feature                   | Minimum Version        | Status       |
| ------------------------- | ---------------------- | ------------ |
| Core Runes                | Svelte 5.0.0           | Stable       |
| Spring/Tween Classes      | Svelte 5.8.0           | Stable       |
| Attachments               | Svelte 5.29.0          | Stable       |
| `$app/state`              | SvelteKit 2.12.0       | Stable       |
| Remote Functions          | SvelteKit 2.27.0       | Experimental |
| Async SSR                 | Svelte 5.36 / Kit 2.43 | Experimental |
| Vitest (Svelte 5 support) | Vitest 3.0.0+          | Stable       |
| vitest-browser-svelte     | 1.0.0+                 | Stable       |

---

_Based on official Svelte documentation and production experience._
