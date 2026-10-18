# Repository setup runbook

## Local initialization
1. Review `.gitignore` and ensure source exports, credentials, local DB files and environment files are not committed.
2. From the repository root run `git init`, `git add .`, and `git commit -m "chore: establish phase 1 and phase 2 warehouse foundation"`.
3. Create an empty repository on GitHub named `commercial-revenue-intelligence-warehouse`.
4. Add the GitHub URL as `origin`, then push the default branch.

This package can initialize the local Git repository, but publishing to GitHub requires the user's authenticated GitHub session or a configured remote; no remote has been configured in this environment.
