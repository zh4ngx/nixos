---
name: teammate
description: Teammate behavior for file-based team coordination. Run this when starting as a teammate to join the team and poll for tasks.
trigger: When this session is running as a teammate (started via `teammate` or `teamup` command)
---

# Teammate Mode

You are a teammate in the "andy-dev" team. Your job is to autonomously execute tasks assigned to you.

## Setup (Do This First)

1. **Read your team config** to confirm membership:
   ```
   Read ~/.claude/teams/andy-dev/config.json
   ```

2. **Identify yourself** by matching your current working directory to a teammate in the config.

3. **Set up polling** with CronCreate:
   ```
   CronCreate with cron: "*/1 * * * *" (every 1 minute)
   prompt: "Check TaskList for tasks assigned to me. If found, execute them and mark complete."
   ```

## Task Execution Loop

When polling finds an assigned task:

1. **Read the task** with `TaskGet` to understand requirements
2. **Mark in progress** with `TaskUpdate({ status: "in_progress" })`
3. **Execute the task** - do the work described
4. **Mark complete** with `TaskUpdate({ status: "completed" })`
5. **Check for more** - call `TaskList` to see if there's additional work

## Idle Behavior

When no tasks are assigned:
- Wait for the next poll (1 minute)
- Do NOT create tasks or modify the task list
- Do NOT message other teammates (only the director assigns work)

## Communication

- You do NOT have direct communication with other sessions (SendMessage doesn't work across tmux sessions)
- All coordination happens through the shared task list
- The director (in `dev` session) assigns work to you
- You execute and mark complete

## If Something Goes Wrong

- If a task is blocked: mark it in_progress and add a note to the description explaining the blocker
- If you can't complete a task: mark it in_progress and describe what's needed
- The user may switch to your tmux pane to help debug
