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
   prompt: "Check for task files assigned to me. If found, execute them and update status."
   ```

## Task File Format

Tasks are JSON files in `~/.claude/tasks/andy-dev/`:

```json
{
  "id": "1",
  "subject": "Brief task title",
  "description": "Detailed description with steps and context",
  "status": "pending | in_progress | completed | blocked",
  "owner": "your-teammate-name",
  "notes": "Optional: human clarifications or additional context",
  "blockedBy": [],
  "blocks": []
}
```

## Task Execution Loop

When polling finds a task where `owner` matches your name AND `status` is `pending`:

1. **Read the task file** with `Read` tool to understand requirements
2. **Check for human notes** in the `notes` field - this contains clarifications from the user
3. **Mark in progress** by updating the file with `status: "in_progress"`
4. **Execute the task** - do the work described
5. **Mark complete** by updating the file with `status: "completed"`
6. **Check for more** - read other task files to see if there's additional work

## File Operations

Use the Read and Edit tools directly on task files:

```
# Read task
Read ~/.claude/tasks/andy-dev/1.json

# Update status
Edit ~/.claude/tasks/andy-dev/1.json
  old_string: "status": "pending"
  new_string: "status": "in_progress"
```

## Human Interjection

The human can intervene in several ways:

1. **Attach to your session**: `teammate <name>` lets them type directly
2. **Add notes to task**: Director can add a `notes` field with clarifications
3. **Change status**: Setting `status: "blocked"` signals you should pause

If you see `status: "blocked"` or new content in `notes`, pause and wait for human guidance before continuing.

## Idle Behavior

When no tasks are assigned:
- Wait for the next poll (1 minute)
- Do NOT create tasks or modify the task list
- Do NOT message other teammates (only the director assigns work)

## Communication

- You do NOT have direct communication with other sessions (SendMessage doesn't work across tmux sessions)
- All coordination happens through the shared task files
- The director (in `dev` session) creates and assigns tasks
- You execute and update status

## If Something Goes Wrong

- If a task is blocked: update `status` to `"blocked"` and add explanation to `notes`
- If you can't complete a task: update `status` to `"blocked"` with details in `notes`
- The user may attach to your tmux session to help debug
