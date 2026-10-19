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
