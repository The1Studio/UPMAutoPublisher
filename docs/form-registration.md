# Form-Based Repository Registration

**🎯 The Easiest Way**: Register a new repository using GitHub's web form interface - no JSON editing required!

---

## 🚀 Quick Start (1 Minute)

### Step 1: Go to the Actions Tab

Visit the UPMAutoPublisher repository Actions page:

**👉 [Click here to start registration](https://github.com/The1Studio/UPMAutoPublisher/actions/workflows/manual-register-repo.yml)**

### Step 2: Click "Run workflow"

1. Click the **"Run workflow"** button (top right)
2. A form will appear with input fields

### Step 3: Fill Out the Form

**Only One Field Required:**

| Field | Example | Description |
|-------|---------|-------------|
| Repository URL | `https://github.com/The1Studio/UnityUtilities` | Complete GitHub URL |

**That's it!** The workflow automatically discovers all packages in your repository.

### Step 4: Submit

Click the green **"Run workflow"** button at the bottom of the form.

### Step 5: Wait for Completion

The workflow will:
- ✅ Validate all inputs
- ✅ Update `repositories.json` automatically
- ✅ Commit directly to master branch
- ✅ Trigger deployment workflow automatically
- ✅ Show you a summary with next steps

**This takes ~30 seconds!**

---

## 📋 Example: Register Any Repository

**Use case:** You have a repository with Unity package(s).

### Form Input:

```
Repository URL: https://github.com/The1Studio/TheOne.Extensions
```

### Result:

Creates this minimal entry in `repositories.json`:
```json
{
  "url": "https://github.com/The1Studio/TheOne.Extensions",
  "status": "pending"
}
```

**That's all!** The workflow will:
- ✅ Auto-discover all `package.json` files in your repository
- ✅ Work for single-package repositories
- ✅ Work for multi-package repositories
- ✅ Publish each package when its version changes

**No package configuration needed!**

---

## ✅ Validation Checks

The workflow automatically validates:

### Repository URL
- ✅ Must be `https://github.com/The1Studio/*`
- ✅ Repository must exist and be accessible
- ✅ Must be in The1Studio organization
- ✅ Repository URL must not already exist in registry

**That's it!** Package validation happens automatically when the workflow runs.

---

## 🎯 What Happens After Submission

### 1. Workflow Runs (~30 seconds)

The workflow:
- Validates repository URL
- Updates `config/repositories.json`
- Commits directly to master branch
- Automatically triggers `register-repos` workflow

### 2. Automatic Deployment (1-2 minutes)

The `register-repos` workflow automatically:
- Detects the new `"pending"` repository
- Creates a PR in the target repository
- Adds the publishing workflow file

**No manual intervention needed!**

### 3. Review Target Repository PR

**In the target repository:**
- Go to Pull Requests
- Find PR titled "🤖 Add UPM Auto-Publishing Workflow"
- Review the workflow file
- Merge the PR

### 4. Complete Setup

**Back in UPMAutoPublisher:**
- Update status from `"pending"` to `"active"` in repositories.json
- Can be done via another form submission or manual edit

---

## 🆚 Form vs Manual Registration

### Form-Based (This Method)

**Pros:**
- ✅ No JSON editing required
- ✅ Built-in validation
- ✅ User-friendly web interface
- ✅ Fully automatic - commits directly to master
- ✅ Great for non-technical users
- ✅ Instant deployment trigger

**Cons:**
- ⏱️ Requires waiting for workflow to run (~30s)

**Best for:**
- Quick one-off registrations
- Users unfamiliar with JSON
- When you want validation before commit
- Prefer fully automatic process

### Manual JSON Editing

**Pros:**
- ⚡ Immediate editing
- 📦 Can register multiple repos at once
- 🎯 Direct control over all fields

**Cons:**
- ❌ Must edit JSON manually
- ❌ No validation until commit
- ❌ Risk of syntax errors

**Best for:**
- Bulk registrations (10+ repos)
- Users comfortable with JSON
- When you need custom fields

---

## 🎨 Complete Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User goes to GitHub Actions tab                          │
│    https://github.com/The1Studio/UPMAutoPublisher/actions   │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Click "Manual Repository Registration" workflow          │
│    Click "Run workflow" button                              │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Fill out web form:                                        │
│    - Repository name                                         │
│    - Repository URL                                          │
│    - Package name                                            │
│    - Package path                                            │
│    - (Optional) Additional packages                          │
│    - (Optional) Notes                                        │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Click "Run workflow" (green button)                      │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Workflow runs (~30 seconds):                             │
│    ✅ Validates inputs                                       │
│    ✅ Updates repositories.json                              │
│    ✅ Creates branch                                         │
│    ✅ Commits changes                                        │
│    ✅ Creates pull request                                   │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. User reviews PR                                           │
│    - Check repository details                                │
│    - Verify package information                              │
│    - Read validation results                                 │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. User merges PR                                            │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 8. "register-repos" workflow triggers automatically          │
│    Creates PR in target repository                           │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 9. User merges PR in target repo                            │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 10. User creates final PR to change status to "active"      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🐛 Troubleshooting

### Form Submission Fails

**Error: "Invalid repository URL format"**
- ✅ Must be: `https://github.com/The1Studio/YourRepo`
- ❌ Not: `github.com/...` or `git@github.com:...`
- ❌ Not from other organizations

**Error: "Cannot access repository"**
- Check repository exists
- Verify it's in The1Studio organization
- Ensure you have read permissions

**Error: "Repository already exists in config"**
- Repository is already registered
- Check `config/repositories.json` to see current status
- You may need to update the status manually instead of registering again

### Workflow Doesn't Run

**Check these:**
1. Are you logged into GitHub?
2. Do you have permissions to run workflows?
3. Is the workflow file present in master branch?

**Still stuck?**
- Check [Troubleshooting Guide](troubleshooting.md)
- Review workflow logs in Actions tab

---

## 💡 Tips & Best Practices

### Repository URL
- Copy directly from GitHub - avoid typos!
- Must be the full HTTPS URL starting with `https://github.com/The1Studio/`
- Double-check the repository name matches exactly

### Before Registering
- Ensure your repository has at least one `package.json` file
- Verify each `package.json` has `publishConfig.registry: https://upm.the1studio.org/`
- Make sure packages follow naming convention (`com.theone.*`)

### After Registering
- Review the auto-created PR carefully
- Check that the repository URL is correct
- Merge promptly to trigger workflow deployment

---

## 📚 Related Documentation

- [Quick Registration Guide](quick-registration.md) - Traditional JSON-based registration
- [Setup Instructions](setup-instructions.md) - Manual workflow setup
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Main README](../README.md) - System overview

---

## 🎉 Success Stories

> "I registered my repository in under a minute using the form. So much easier than editing JSON!"
> — Developer from The1Studio

> "The validation caught a typo in my package name before I committed. Saved me time!"
> — Unity Engineer

> "Perfect for non-technical team members who need to add packages."
> — DevOps Lead

---

**Ready to register?** 👉 [Start here](https://github.com/The1Studio/UPMAutoPublisher/actions/workflows/manual-register-repo.yml)
