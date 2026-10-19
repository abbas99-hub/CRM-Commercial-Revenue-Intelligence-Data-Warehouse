# Publishing this repository to GitHub

1. Create an empty public or private GitHub repository, e.g. `commercial-revenue-intelligence-data-warehouse`.
2. From the project root:

```bash
git init
git add .
git status --short
git commit -m "Package commercial revenue intelligence warehouse portfolio"
git branch -M main
git remote add origin https://github.com/<your-user>/commercial-revenue-intelligence-warehouse.git
git push -u origin main
```

4. Replace `[add your GitHub repository URL]` in both story drafts after the repository is created.
5. Enable the repository's Issues and add milestones for SQL runtime validation, permission tests and LLM integration.
6. Do not commit connection strings, passwords, private data exports or local database files. The `.gitignore` excludes common secrets and database artifacts.

The repository is prepared locally; this workflow does not publish it automatically. Authenticated GitHub access and a destination repository are required to push.
