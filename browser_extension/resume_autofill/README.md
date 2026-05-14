# Resume Autofill Browser Extension

This extension is the browser-side executor for F-module resume autofill.

## Current architecture

1. `content.js`
   - generic fill engine
   - fallback matching for visible `input / textarea / select`
2. `site-strategies.js`
   - site-specific strategy registry
   - reserved for explicit actions such as dropdowns, date pickers, and add buttons
3. `popup.js`
   - loads local resume data from `http://127.0.0.1:8798/api/resume/profile`
   - triggers fill on the active tab
   - reports strategy hits vs generic fallback hits

## Current capability

- Read `profile` and `flat_map` from the local service
- Try site strategy first when the current host matches
- Fall back to generic field matching when no site action is available

## Implemented site strategy

Current first implemented site strategy: `Bilibili`

- `basic_info_strategy`
  - name
  - gender
  - birth date
  - city
  - phone
  - email
- `education_group_strategy`
  - school
  - month range
  - major
  - degree
- `experience_group_strategy`
  - company
  - month range
  - role
  - description
- `project_group_strategy`
  - project name
  - month range
  - project role
  - project description
  - project link

Current explicit skips:

- attachments/upload widgets
- internal referral code
- fields requiring semantic/manual judgment

## Near-term goal

Reach 90%+ fill rate by layering:

- generic direct-fill support
- company/site strategies
- issue-driven iteration from screenshots and failed samples

## Working rule

Do not keep adding UI complexity in the Web editor to chase fill rate.  
Prefer encoding site-specific behavior in the extension strategy layer.
