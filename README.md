# GymBro

GymBro is a Phoenix + LiveView fitness coaching platform for athletes and trainers.


<img width="1440" height="814" alt="Screenshot 2026-06-07 at 15 32 36" src="https://github.com/user-attachments/assets/d0e60703-8fd4-4b74-bcd9-94aa8a45e326" /><img width="1440" height="814" alt="Screenshot 2026-06-07 at 15 33 27" src="https://github.com/user-attachments/assets/7b2458e4-4017-4a25-976e-6c9d54c5b858" />

<img width="1440" heigh="814" alt="Screenshot 2026-06-07 at 15 33 34" src="https://github.com/user-attachments/assets/306610a6-889b-4f51-9f97-5614318e2493" />

<img width="1440" height="814" alt="Screenshot 2026-06-07 at 15 19 28" src="https://github.com/user-attachments/assets/59e41bbf-6393-4c67-b98a-e7c81f48455b" />
<img width="1440" height="814" alt="Screenshot 2026-06-07 at 15 12 09" src="https://github.com/user-attachments/assets/d8bc348b-c403-4f91-9c83-ab27de79c1c0" />


Athletes use GymBro to get an AI-generated workout plan, log sessions, and track progress. Trainers use it to invite clients, monitor activity, adjust programs, and review analytics from one dashboard.

## How the app works

### Athlete flow

1. A user signs up and chooses the `athlete` role.
2. The athlete completes onboarding:
   - body stats
   - training goal
   - experience level
   - equipment
   - preferred training frequency
3. GymBro generates a structured workout plan with AI.
4. The athlete lands in their app area where they can:
   - view the next workout
   - open workout details
   - start and log sessions live
   - track weight, check-ins, and progress photos
   - review consistency and dashboard metrics

### Trainer flow

1. A user signs up and chooses the `trainer` role.
2. The trainer completes trainer setup.
3. The trainer can then:
   - invite clients with secure links
   - manage a client roster
   - view client details and progress
   - edit or override exercises in a client plan
   - regenerate plans with AI
   - monitor live workout sessions
   - review trainer analytics

## Main features

- Role-based authentication for athletes and trainers
- Guided onboarding flows
- AI workout plan generation with structured JSON parsing
- Workout programs, days, and exercises
- Live workout logging for sets, reps, weight, and rest
- Bodyweight logs, check-in images, and personal records
- Trainer dashboard, client management, and analytics
- Invitation flow that links athletes to trainers

## Main app routes

- `/` public landing page
- `/join/role` role selection before registration
- `/users/register` user registration
- `/users/log_in` user login

### Athlete routes

- `/home`
- `/workouts`
- `/workouts/:id`
- `/workouts/session/:session_id`
- `/body-stats`
- `/settings`

### Trainer routes

- `/trainer`
- `/trainer/analytics`
- `/trainer/clients`
- `/trainer/clients/invite`
- `/trainer/clients/:client_id`

## Tech stack

- Elixir
- Phoenix 1.7
- Phoenix LiveView
- Ecto + PostgreSQL
- Tailwind CSS
- Swoosh for email
- OpenAI API for plan generation

## Local setup

### Prerequisites

- Elixir 1.14+
- Erlang/OTP compatible with your Elixir version
- PostgreSQL

### Install and boot

```bash
mix setup
mix phx.server
```

Then open `http://localhost:4000`.

`mix setup` will:

- fetch dependencies
- create and migrate the database
- run seeds
- install frontend tooling
- build assets

## Environment variables

GymBro loads a local `.env` file automatically in non-production environments if it exists.

### Common local variables

```env
OPENAI_API_KEY=your_openai_api_key
```

`OPENAI_API_KEY` is required for AI plan generation. If it is missing, the app still runs, but plan generation and regeneration will fail gracefully.

### Production variables

These are required in production:

```env
DATABASE_URL=ecto://USER:PASS@HOST/DATABASE
SECRET_KEY_BASE=your_secret_key_base
PHX_HOST=your-domain.com
PORT=4000
PHX_SERVER=true
```

## Development notes

- The landing page lives at `/` and is rendered by `GymBroWeb.HomeLive`.
- Athlete app pages are under `GymBroWeb.Athlete.*`.
- Trainer app pages are under `GymBroWeb.Trainer.*`.
- AI plan generation is handled by `GymBro.AI.PlanGenerator` and `GymBro.OpenAI`.
- In development, local emails can be previewed at `/dev/mailbox`.

## Test

Run the test suite with:

```bash
mix test
```

## Project structure

- `lib/gym_bro/accounts` authentication and user management
- `lib/gym_bro/profiles` athlete and trainer profiles
- `lib/gym_bro/programs` workout programs, days, and exercises
- `lib/gym_bro/training` workout sessions and exercise logs
- `lib/gym_bro/body_stats` weight logs, images, and PRs
- `lib/gym_bro/trainer` trainer-client relationships and invitations
- `lib/gym_bro/ai` plan generation and parsing
- `lib/gym_bro_web/live` LiveView screens

## Goal of the product

GymBro is designed to help athletes stay consistent with personalized training, while giving trainers a practical system for coaching clients, tracking progress, and making better training decisions.
