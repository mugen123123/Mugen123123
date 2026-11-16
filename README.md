# Homework Assistant

My personal homework workspace. Claude reads `CLAUDE.md` at the start of every session, so the rules for how it works (writing style, answer format, file organization, quality checks) are always applied.

## How to use it

1. Put the assignment files in `Homework/_Inbox/`. You can upload them to this repo on GitHub, or attach them in the chat.
2. Tell Claude: "Do the homework in the inbox." Add the due date and any instructions the teacher gave out loud.
3. Claude reads everything, sums up what's needed, does the work, makes any slides or documents, checks it, and gives a final report.
4. Finished files end up in `Homework/<Subject>_<Assignment>/Completed_Work/` (slides in `Presentations/`).

Claude asks before submitting anything or contacting a teacher.

## Folder layout

```
Homework/
  _Inbox/          new materials go here
  _Template/       blank structure copied for each assignment
  Biology_Cell_Structure_Worksheet/   (example)
    Original_Materials/
    Completed_Work/
    Presentations/
    Research/
    Study_Resources/
    ASSIGNMENT_NOTES.md
```
