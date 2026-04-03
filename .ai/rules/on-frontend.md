# Rules: Frontend

Applies when frontend source files are created or modified.

TODO: Adjust paths, patterns, and conventions to match your project.

## Component structure

TODO: Define your project's file/folder conventions:
- Where do pages/routes live?
- Where do shared components live?
- Where do styles live?
- Where do services/API clients live?
- Where do types live?

## Types

- Shared types should be imported from a central location
- Component-specific types defined in same file or local types directory
- API response types should match backend schema
- NEVER use `any` — define correct types

## Loading and Error States

- All async operations must have:
  1. **Loading state** — show indicator while data loads
  2. **Error state** — show meaningful error message
  3. **Empty state** — handle empty data (not just blank page)

## Null Safety

- ALWAYS check that API responses aren't null/undefined before `.length`, `.map()`, etc.
- Use `?? []` for arrays, `?? ''` for strings
- Avoid optional chaining chains that hide bugs — handle null explicitly

## State Management

- Use framework-native state management (React hooks, Vue composition API, etc.)
- No external state libraries unless already present
- Avoid unnecessary global state

## Styles

TODO: Define your styling approach (CSS modules, Tailwind, styled-components, etc.)

## UI/UX requirements

### Touch & interaction (mobile)
- **Touch targets:** At least 44x44pt (Apple HIG) / 48x48dp (Material)
- **Feedback:** Visual feedback on press within 80-150ms
- **Loading buttons:** Disable + spinner during async operations

### Accessibility (CRITICAL)
- **Contrast:** 4.5:1 for normal text, 3:1 for large text (WCAG AA)
- **Semantic HTML:** Use `button`, `nav`, `main`, `label` — not `div` with onClick
- **Forms:** Visible label per input. Error message placed under the field, not in toast.
- **Heading hierarchy:** h1→h2→h3 without skipping levels

### Forms & feedback
- **Visible labels** — never just placeholder as label
- **Error placement** — under the relevant field, never just in toast
- **Validation** — on blur, not on keystroke
- **Empty states** — helpful message + action, not just empty page
- **Confirmation dialogs** — before destructive operations

## Testing

TODO: Define your frontend testing strategy:
- What test runner? (Jest, Vitest, etc.)
- What testing library? (Testing Library, Enzyme, etc.)
- Where do test files live?
- E2E framework? (Playwright, Cypress, Maestro, etc.)
