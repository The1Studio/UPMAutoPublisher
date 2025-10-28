# Logo Installation Instructions

## Add THE 1 GAME STUDIO Logo

To complete the Discord notification integration, add your logo file:

### Steps:

1. **Save the logo image** as `.github/assets/the1studio-logo.png`
   - Use the vibrant gradient "1" logo with "THE" and "GAME STUDIO" text
   - Recommended format: PNG with transparency
   - Recommended size: 256x256 pixels or larger (Discord will auto-resize)

2. **Commit and push the logo:**
   ```bash
   git add .github/assets/the1studio-logo.png
   git commit -m "Add THE 1 GAME STUDIO logo for Discord notifications"
   git push
   ```

3. **Verify the integration:**
   - Trigger any workflow manually (e.g., build-package-cache.yml)
   - Check Discord - notifications should now show:
     - Username: "THE 1 GAME STUDIO"
     - Avatar: Your studio logo

### Logo URL Used in Workflows:
```
https://raw.githubusercontent.com/The1Studio/UPMAutoPublisher/master/.github/assets/the1studio-logo.png
```

### Workflows Using This Logo:
- build-package-cache.yml - Package cache build notifications
- daily-audit.yml - Daily health check notifications
- monitor-publishes.yml - Publish activity monitoring
- trigger-stale-publishes.yml - Stale package publishing

## Troubleshooting

If the logo doesn't appear after adding the file:
1. Verify the file is named exactly: `the1studio-logo.png` (lowercase, no spaces)
2. Verify the file is in the correct location: `.github/assets/`
3. Check the file was committed and pushed to GitHub
4. Wait ~5 minutes for GitHub's CDN to cache the new file
5. Trigger a workflow to test the integration
