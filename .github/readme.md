Yes — that's the problem. GitHub Actions only looks for workflows in workflows. A root-level workflows/ folder is just a regular folder GitHub ignores for automation.

What you need to do:

Delete the root workflows folder from GitHub (open it → click the file → edit → delete)
Delete the root scripts folder the same way
Re-create them at the correct paths using Add file → Create new file:
Type scheduled-release.yml → paste the YML
Type release_articles.py → paste the Python
When you type .github as the start of the filename in GitHub's UI, it will automatically create the hidden .github folder. After saving, your repo root should show a .github folder (GitHub displays it with the dot).

The articles folder you uploaded looks correct — leave that as-is. Only the scripts and workflows folders need to move.

