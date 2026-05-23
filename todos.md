# GymBro — Todos

Tackle one section at a time. Check off subtasks as we go.

---

## 1. Auth + Role Selection
- [x] Run `mix phx.gen.auth` for email/password auth
- [x] Add `role` field to `users` (default `"athlete"`)
- [x] Build `/join/role` LiveView (Athlete vs Trainer cards)
- [x] Store selected role in session, write to user on registration

## 2. Migrations (in dependency order)
- [x] `users` (extend with role)
- [x] `trainer_profiles`
- [x] `trainer_clients` (unique index on `[:trainer_id, :client_id]`)
- [x] `client_invitations`
- [x] `user_profiles`
- [x] `programs`
- [x] `workout_days`
- [x] `exercises`
- [x] `trainer_exercise_overrides`
- [x] `workout_sessions`
- [x] `exercise_logs`
- [x] `body_weight_logs`
- [x] `checkin_images`
- [x] `personal_records`

## 3. Contexts
- [x] `Accounts`
- [x] `Profiles` (user_profile + trainer_profile)
- [x] `Trainer` (trainer_clients, client_invitations, exercise_overrides)
- [x] `Programs`
- [x] `Training`
- [x] `BodyStats`
- [x] `Analytics`

## 4. Authorization
- [x] `RequireTrainer` on_mount hook
- [x] `RequireAthlete` on_mount hook
- [x] `Trainer.verify_client_access/2`

## 5. Onboarding
- [x] Welcome screen
- [x] Body stats step
- [x] Goals step
- [x] Athlete branch → Generating screen → Home
- [x] Trainer branch → Trainer setup → `/trainer`

## 6. AI Plan Generation
- [x] `GymBro.AI.PlanGenerator.generate/2` (alias existing `OpenAI`)
- [x] `GymBro.AI.PlanParser` (parse JSON → programs/days/exercises)
- [x] Store raw JSON in `programs.ai_raw_plan`

## 7. Athlete Home Dashboard
- [x] Next workout card
- [x] Macros card
- [x] Bodyweight chart (SVG)
- [x] Steps bar chart (SVG)
- [x] Consistency progress ring

## 8. Athlete Workout Flow
- [x] Workout list view
- [x] Workout day detail view
- [x] Active workout LiveView (set logger)
- [x] PubSub rest timer (`workout:#{session_id}`)
- [x] Broadcast set logs to `client_session:#{user_id}`

## 9. Athlete Body Stats
- [x] Weight log + chart
- [x] Check-in image upload
- [x] Progress photo upload

## 10. Trainer Dashboard (`/trainer`)
- [x] Client avatar row (horizontal scroll)
- [x] Live session indicator (green pulsing dot)
- [x] Today's activity feed
- [x] Attention alerts (missed sessions, no check-in)

## 11. Client List + Detail
- [x] `/trainer/clients` list with search
- [x] Client detail with tabs: Stats | Program | Photos | PRs
- [x] Add exercise to a client's day
- [x] Edit / override exercise (TrainerExerciseOverride)
- [x] Remove exercise from a day
- [x] Trainer notes per exercise
- [x] Regenerate plan with AI (with trainer notes)

## 12. Client Invitation
- [x] Invite form `/trainer/clients/invite`
- [x] Token generation (48h expiry)
- [x] Swoosh email
- [x] `/join/:token` accept flow
- [x] Auto-create `trainer_clients` link on registration

## 13. Live Session Watch
- [x] Trainer subscribes to `client_session:#{client.id}`
- [x] Read-only live view of sets being logged
- [x] Trainer → client message toast

## 14. Trainer Analytics
- [x] Total sessions across clients
- [x] Avg consistency
- [x] Weight loss leaders / aggregate stats

## 15. Nav Layouts
- [x] Athlete bottom nav (`app.html.heex`)
- [x] Trainer bottom nav with purple accent (`trainer_app.html.heex`)
- [x] Conditional render based on `current_user.role`

## 16. Polish
- [x] Dark theme Tailwind tokens
- [x] Mobile viewport (390px) + iOS safe area insets
- [x] Toast system
- [x] Animations / transitions
