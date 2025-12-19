This document has been moved to the documentation folder: [docs/TERRAFORM_PUSH_BEHAVIOR.md](docs/TERRAFORM_PUSH_BEHAVIOR.md)

---

## How Terraform Works on Each Push

### Current GitHub Actions Flow

```
1. You push to main branch
    ↓
2. GitHub Actions triggers automatically
    ↓
3. TEST JOB (always runs)
    ├─ Run pytest (unit tests)
    ├─ Check code formatting (black, flake8)
    └─ If ANY test fails → STOP (don't deploy)
    
4. BUILD & DEPLOY JOB (only on successful tests)
    ├─ Package Lambda code
    ├─ Run: terraform init
    ├─ Run: terraform plan -out=tfplan
    │   └─ Shows what WILL change (review stage)
    │
    └─ Run: terraform apply tfplan
        ├─ CREATE new resources (if not in AWS)
        ├─ UPDATE changed resources (if code changed)
        ├─ LEAVE unchanged resources (no action)
        └─ NEVER destroy anything
```

---

## Terraform Commands Explained

### What `terraform plan` Does
```bash
terraform plan -out=tfplan
```

**Shows:**
- ✅ Resources to be CREATED (new)
- 📝 Resources to be MODIFIED (changed)
- ➡️ Resources to remain UNCHANGED (no action)
- ❌ Resources to be DESTROYED (only if explicitly deleted from code)

**Example output:**
```
Terraform will perform the following actions:

  # aws_lambda_function.ray_converter will be created
  + resource "aws_lambda_function" "ray_converter" {
      + arn = (known after apply)
      + filename = "build/ray_converter.zip"
      + ...
    }

  # aws_apigatewayv2_api.http_api will be updated in-place
  ~ resource "aws_apigatewayv2_api" "http_api" {
      ~ cors_configuration = (computed)
      ...
    }

  # aws_cloudwatch_log_group.ray_converter_logs will be updated in-place
  ~ resource "aws_cloudwatch_log_group" "ray_converter_logs" {
      ~ retention_in_days = 14 -> 30  # If you changed this
    }

Plan: 3 to add, 1 to modify, 0 to destroy.
```

### What `terraform apply` Does
```bash
terraform apply tfplan
```

**Executes the plan:**
- ✅ Actually creates new resources in AWS
- ✅ Actually updates changed resources
- ✅ Skips everything else
- ❌ Does NOT delete anything

---

## Scenario Walkthroughs

### Scenario 1: You Push Updated Lambda Code

```
Old code:
  handler.py → processes "x" field
  
New code:
  handler.py → processes "x" AND "y" fields
  
When you push:
  ✅ Terraform detects: handler.py changed
  ✅ Terraform re-zips code
  ✅ Terraform UPDATES the Lambda with new zip
  ✅ Infrastructure stays the same
  ✅ NO DOWNTIME (Lambda hot swap)
```

**Result:** Only Lambda function updated, everything else unchanged ✅

---

### Scenario 2: You Add New CloudWatch Alarm

```
Old code:
  cloudwatch.tf → 5 alarms
  
New code:
  cloudwatch.tf → 6 alarms (added 1 new)

When you push:
  ✅ Terraform sees 5 alarms already exist
  ✅ Terraform creates the NEW 1 alarm
  ✅ Terraform skips the existing 5
  ✅ No changes to old alarms
```

**Result:** 1 new alarm created, 5 existing alarms untouched ✅

---

### Scenario 3: You Change Lambda Memory Size

```
Old code:
  memory_size = 128
  
New code:
  memory_size = 256

When you push:
  ✅ Terraform detects change
  ✅ Terraform shows in plan: "memory_size = 128 -> 256"
  ✅ Terraform UPDATES Lambda (may cause brief restart)
  ✅ No other resources affected
```

**Result:** Lambda memory increased, API Gateway unchanged ✅

---

### Scenario 4: You Add New Trigger (SQS)

```
Old code:
  Only API Gateway trigger
  
New code:
  API Gateway + SQS trigger enabled

When you push:
  ✅ Terraform sees API Gateway exists
  ✅ Terraform creates NEW SQS queue
  ✅ Terraform creates NEW Lambda-SQS mapping
  ✅ Terraform skips API Gateway (unchanged)
```

**Result:** New SQS trigger added, API Gateway still working ✅

---

### Scenario 5: You Remove Code, Then Push

```
Old infra/triggers.tf:
  resource "aws_sqs_queue" "ray_queue" { ... }

You delete this from triggers.tf

New push:
  terraform plan shows: "resource will be destroyed"
  ❌ BUT terraform apply WILL destroy the SQS queue!
```

**WARNING:** Deleting code = resource gets destroyed on next apply! 🚨

---

## 🔒 Safe Defaults

Your GitHub Actions workflow is **safe by design**:

1. **Always runs tests first**
   - If tests fail → Deploy is BLOCKED
   - Bad code never makes it to AWS

2. **Uses `terraform plan` first**
   - Shows what will change before applying
   - You can review in GitHub Actions logs

3. **Never auto-destroys**
   - Only creates/updates
   - Must manually run `terraform destroy`

4. **Only deploys from main branch**
   - Development branches just run tests
   - Only main branch triggers deployment

---

## 📋 When Terraform DOES Destroy

Resources are **ONLY destroyed** in these cases:

### Case 1: You manually delete from code
```terraform
# Remove this from your .tf file
resource "aws_sqs_queue" "ray_queue" {
  name = "ray-converter-queue"
}

# Then push → Terraform destroys the queue
```

### Case 2: You manually run destroy command
```bash
cd infra
terraform destroy
# This destroys EVERYTHING
```

### Case 3: You use `-auto-approve` flag
```bash
terraform apply -auto-approve
# Auto-applies without review (NOT recommended)
```

### Case 4: Resource conflicts during import
```bash
terraform import aws_lambda_function.ray_converter arn:aws:lambda:...
# If importing fails and removed from code
```

**Your GitHub Actions uses NONE of these** ✅

---

## 📊 State Management

### Terraform State File (`terraform.tfstate`)

This file tracks **what currently exists in AWS**:

```json
{
  "resources": [
    {
      "type": "aws_lambda_function",
      "name": "ray_converter",
      "id": "ray-converter",
      "instances": [
        {
          "attributes": {
            "function_name": "ray-converter",
            "filename": "build/ray_converter.zip",
            "memory_size": 128,
            ...
          }
        }
      ]
    }
  ]
}
```

**How Terraform Uses It:**
1. Code says: "Lambda should have 256 MB memory"
2. State says: "Lambda currently has 128 MB"
3. Terraform: "Need to update from 128 → 256"
4. Terraform applies the change

**Each push:**
- Terraform compares: **Code** vs **State** vs **AWS Reality**
- Updates state file after successful apply
- Next push uses updated state

---

## 🚀 Typical Push Workflow

### Step 1: Make Code Changes
```bash
# Edit handler.py
code functions/ray_converter/handler.py

# Edit tests if needed
code functions/ray_converter/tests/test_handler.py
```

### Step 2: Test Locally
```bash
pytest functions/ray_converter/tests/ -v
```

### Step 3: Commit & Push
```bash
git add functions/
git commit -m "Update handler to process Y field"
git push origin main
```

### Step 4: GitHub Actions Runs (automatic)
```
✅ Tests run
✅ Code passes formatting checks
✅ Build package created
✅ Terraform plan shows changes
✅ Terraform apply executes
✅ Lambda updated with new code
```

### Step 5: New Code is LIVE
Your updated Lambda handles requests immediately! 🎉

---

## ⚠️ Important Notes

### Note 1: Infrastructure is NOT Destroyed on Push
- Code changes = Lambda updated ✅
- Infrastructure changes = Resources added/updated ✅
- Infrastructure is safe and persistent
- Previous deployments are preserved

### Note 2: Database-Like Behavior
Terraform behaves like a database with these operations:
- `CREATE` - New infrastructure
- `READ` - Check current state
- `UPDATE` - Modify existing
- `DELETE` - Only if explicitly removed

(Not all together, it's safe!)

### Note 3: State File is Critical
- Stores in `infra/terraform.tfstate`
- Should be backed up
- For production, use S3 backend (optional)
- GitHub Actions can't share state between runs without setup

### Note 4: Concurrent Pushes
If 2 people push simultaneously:
- First push succeeds
- Second push may conflict with state
- Solution: Use S3 backend with state locking

---

## 📈 Safe Deployment Best Practices

### ✅ DO:

1. **Run tests locally first**
   ```bash
   pytest functions/ray_converter/tests/ -v
   ```

2. **Review GitHub Actions logs**
   - Check `terraform plan` output
   - Verify changes are expected

3. **Keep infra code in sync**
   - Commit both code and infra changes together
   - All in same `git push`

4. **Use branches for big changes**
   ```bash
   git checkout -b feature/add-sqs-trigger
   # Make changes
   git push origin feature/add-sqs-trigger
   # Creates PR for review
   ```

5. **Backup state file periodically**
   ```bash
   cp infra/terraform.tfstate infra/terraform.tfstate.backup
   ```

### ❌ DON'T:

1. ❌ Don't manually delete AWS resources
   - Terraform state gets out of sync
   - Next apply may recreate unexpectedly

2. ❌ Don't manually change AWS in console
   - Terraform thinks state is correct
   - Changes get overwritten on next apply

3. ❌ Don't push if tests fail
   - GitHub Actions blocks deployment automatically
   - Fix tests before pushing

4. ❌ Don't use `terraform destroy` casually
   - Destroys ALL infrastructure
   - Hard to recreate

5. ❌ Don't commit sensitive data
   - API keys, passwords in code
   - They'll be in git history forever

---

## 🔍 Inspect Changes Before Applying

### In GitHub Actions UI:

1. **Trigger build**
   ```bash
   git push origin main
   ```

2. **Go to GitHub**
   - Your repo → Actions tab
   - Find your workflow run
   - Click to expand "Deploy with Terraform"

3. **Review terraform plan output**
   ```
   + resource "aws_lambda_function" "ray_converter" {
       + arn = (known after apply)
       + filename = "build/ray_converter.zip"
   }
   ```

4. **Confirm changes**
   - If looks good, deployment continues
   - If looks wrong, cancel the run

### From Terminal:

```bash
cd infra
terraform plan -out=tfplan
# Review output carefully

# If looks good:
terraform apply tfplan

# If looks wrong:
rm tfplan  # Cancel it
```

---

## 📝 Summary Table

| Action | What Happens | Infrastructure | AWS Resources |
|--------|---|---|---|
| Push code update | Lambda updated | Unchanged | Same |
| Push infra addition | New resource created | Expanded | New added |
| Push infra modification | Resource updated | Modified | Same but changed |
| Push with code deletion | ⚠️ Can break things | Could shrink | Could be deleted |
| Manual `destroy` | ❌ Everything deleted | Wiped | All gone |
| Pull code change | No effect | Unchanged | Unchanged |

---

## 🆘 If Something Goes Wrong

### My Lambda Broke After Push

**Solution:**
```bash
# Revert the push
git revert HEAD
git push

# GitHub Actions auto-deploys the revert
# Lambda goes back to previous version
```

### Infra Got Messed Up

**Solution:**
```bash
cd infra
terraform plan
# Review what it will do

terraform apply  # Carefully read plan first
```

### State File is Out of Sync

**Solution:**
```bash
# Refresh state
terraform refresh

# Or reimport resource
terraform import aws_lambda_function.ray_converter ray-converter
```

---

## ✨ Key Takeaway

**Your infrastructure is SAFE:**
- ✅ Nothing gets destroyed on push (unless you delete from code)
- ✅ Old infrastructure persists
- ✅ Updates are additive and safe
- ✅ Tests block bad deployments
- ✅ You control what changes happen

**Your Lambda function is SAFE:**
- ✅ Code updates = just Lambda redeployed
- ✅ No downtime (usually instant)
- ✅ Rollback = just `git revert` and push again
- ✅ Previous version recoverable from git

**Everything is tracked:**
- ✅ Git tracks code changes
- ✅ Terraform state tracks infra changes
- ✅ AWS CloudTrail tracks resource changes
- ✅ CloudWatch tracks Lambda execution logs

**You're good to push with confidence!** 🚀

---

## 📚 Need More Details?

- **How Terraform Works:** https://www.terraform.io/docs/intro/index.html
- **Terraform Best Practices:** https://www.terraform.io/docs/cloud/guides/recommended-practices.html
- **GitHub Actions:** https://docs.github.com/en/actions
- **Your GitHub Actions Workflow:** `.github/workflows/deploy.yml`
