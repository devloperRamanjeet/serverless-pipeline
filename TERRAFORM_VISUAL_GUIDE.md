This document has been moved to the documentation folder: [docs/TERRAFORM_VISUAL_GUIDE.md](docs/TERRAFORM_VISUAL_GUIDE.md)

```
┌─────────────────────────────────────────────────────────────────┐
│                    YOU PUSH TO GITHUB                            │
│              git push origin main                                 │
└─────────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│              GITHUB ACTIONS TRIGGERED                            │
│        .github/workflows/deploy.yml starts running              │
└─────────────────────────────────────────────────────────────────┘
                           ↓
      ┌────────────────────┴────────────────────┐
      ↓                                         ↓
┌──────────────────┐                  ┌──────────────────┐
│   TEST JOB       │                  │   Always runs    │
│   (Always runs)  │                  │   first!         │
└──────────────────┘                  └──────────────────┘
      ↓
┌─────────────────────────────────────────────────┐
│  Step 1: Run pytest                             │
│  Step 2: Check code formatting (black, flake8)  │
│  Step 3: Verify requirements.txt                │
└─────────────────────────────────────────────────┘
      ↓
    ┌─┴─────────────────────────────┐
    │                               │
   YES                             NO
 (tests                         (tests
 passed)                        failed)
    ↓                               ↓
    │                          ❌ STOP!
    │                        Don't deploy
    │                        Fix errors
    ↓
┌─────────────────────────────────────────────────┐
│        BUILD & DEPLOY JOB (only if tests OK)    │
│  (Only runs on main branch, only after test OK) │
└─────────────────────────────────────────────────┘
    ↓
    │
    ├─ Step 1: Package Lambda
    │  ├─ Zip: functions/ray_converter/handler.py
    │  ├─ Include: All dependencies from requirements.txt
    │  └─ Output: build/ray_converter.zip
    │
    ├─ Step 2: Terraform Init
    │  └─ terraform init
    │     ├─ Download AWS provider
    │     ├─ Check existing state
    │     └─ Prepare for deployment
    │
    ├─ Step 3: Terraform Plan (DRY RUN)
    │  └─ terraform plan -out=tfplan
    │     ├─ Compare: Code vs State vs AWS
    │     ├─ Show: What will CREATE, UPDATE, DELETE
    │     └─ Output: tfplan file (recipe)
    │
    └─ Step 4: Terraform Apply (EXECUTE)
       └─ terraform apply tfplan
          ├─ CREATE: New resources (if not in AWS)
          ├─ UPDATE: Changed resources (if code changed)
          ├─ SKIP: Unchanged resources (no action)
          └─ ❌ NEVER: Delete (unless explicitly removed)
    ↓
┌─────────────────────────────────────────────────┐
│  TERRAFORM COMPARES THREE THINGS:              │
├─────────────────────────────────────────────────┤
│                                                 │
│  1. YOUR CODE                                   │
│     ├─ infra/main.tf                           │
│     ├─ infra/triggers.tf                       │
│     ├─ infra/cloudwatch.tf                     │
│     └─ build/ray_converter.zip                 │
│                                                 │
│  2. STATE FILE (terraform.tfstate)             │
│     └─ What Terraform thinks exists in AWS     │
│                                                 │
│  3. AWS REALITY                                │
│     └─ What actually exists in your account    │
│                                                 │
│  THEN:                                          │
│  ✅ If NEW in code → CREATE it                 │
│  ✅ If CHANGED in code → UPDATE it             │
│  ✅ If SAME → SKIP it                          │
│  ❌ If REMOVED from code → DELETE it           │
│                                                 │
└─────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────┐
│          AWS RESOURCES UPDATED                  │
│                                                 │
│  ✅ Lambda Function (if code changed)         │
│  ✅ API Gateway (if config changed)            │
│  ✅ CloudWatch (if config changed)             │
│  ✅ IAM Roles (if permissions changed)         │
│  ✅ Other resources as needed                  │
│                                                 │
└─────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────┐
│        ✅ DEPLOYMENT COMPLETE!                 │
│                                                 │
│  NEW CODE IS LIVE IN AWS                       │
│  Your Lambda is running latest version!        │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## Different Scenarios & What Happens

### Scenario 1: Update Only Lambda Code

```
YOUR CHANGES:
  ├─ functions/ray_converter/handler.py  ← CHANGED
  └─ infra/*.tf                          ← NO CHANGE

TERRAFORM DOES:
  ├─ DETECTS: handler.py changed
  ├─ RE-ZIPS: New build/ray_converter.zip
  ├─ UPDATES: AWS Lambda with new zip
  └─ SKIPS: Everything else (API Gateway, etc)

RESULT IN AWS:
  ✅ Lambda function code updated
  ✅ API Gateway unchanged
  ✅ CloudWatch unchanged
  ✅ Deployment time: ~10 seconds
  ✅ NO DOWNTIME (instant hot swap)
```

### Scenario 2: Add CloudWatch Alarm

```
YOUR CHANGES:
  ├─ infra/cloudwatch.tf  ← ADDED NEW ALARM
  └─ All other files       ← NO CHANGE

TERRAFORM DOES:
  ├─ DETECTS: 5 alarms exist, 6 in code
  ├─ CREATES: 1 new alarm
  ├─ SKIPS: The 5 existing alarms
  └─ SKIPS: Lambda, API Gateway, etc

RESULT IN AWS:
  ✅ New alarm created
  ✅ Old alarms unchanged
  ✅ Lambda unchanged
  ✅ Deployment time: ~5 seconds
  ✅ NO DOWNTIME
```

### Scenario 3: Enable SQS Trigger

```
YOUR CHANGES:
  ├─ config/triggers.yaml       ← sqs.enabled = true
  ├─ infra/triggers.tf          ← SQS config changed
  └─ functions/handler.py       ← Handle SQS events

TERRAFORM DOES:
  ├─ CREATES: SQS queue
  ├─ CREATES: Lambda-SQS mapping
  ├─ UPDATES: Lambda (new code to handle SQS)
  ├─ SKIPS: API Gateway (unchanged)
  └─ SKIPS: Other triggers (unchanged)

RESULT IN AWS:
  ✅ SQS queue created
  ✅ Lambda linked to SQS
  ✅ Lambda can now handle SQS events
  ✅ API Gateway still works (unchanged)
  ✅ Deployment time: ~20 seconds
  ✅ NO DOWNTIME
```

### Scenario 4: Delete Code (Dangerous!)

```
YOUR CHANGES:
  └─ DELETED: infra/triggers.tf  ← API GATEWAY CODE REMOVED!

TERRAFORM DOES:
  ├─ DETECTS: API Gateway exists in state but NOT in code
  ├─ WARNS: "This will be destroyed"
  ├─ DESTROYS: API Gateway, routes, integrations
  └─ DELETES: Lambda permissions for API Gateway

RESULT IN AWS:
  ❌ API Gateway DELETED
  ❌ Your API URL no longer works!
  ❌ Lambda still exists but no HTTP endpoint
  ⚠️ THIS IS DESTRUCTIVE!

HOW TO UNDO:
  1. git revert HEAD
  2. git push
  3. GitHub Actions redeploys everything
  4. API Gateway recreated ✅
```

---

## State Management Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│              TERRAFORM STATE FILE LIFECYCLE                     │
│                  (terraform.tfstate)                            │
└─────────────────────────────────────────────────────────────────┘

INITIAL STATE (first deployment):
  ├─ terraform init
  ├─ terraform apply
  ├─ State file created (empty initially)
  ├─ Resources created in AWS
  └─ State file now has resource info

        ↓

RUNNING STATE (between deployments):
  ├─ State file = "current AWS state"
  ├─ Code = "desired state"
  ├─ AWS = "actual state"
  └─ Terraform ensures: AWS = desired

        ↓

ON NEW PUSH:
  ├─ Load state file
  ├─ Read current code
  ├─ Query AWS for actual state
  ├─ Compare all three
  ├─ Calculate differences
  ├─ Apply changes if needed
  └─ UPDATE state file with new info

        ↓

UPDATED STATE (after deployment):
  ├─ State file updated
  ├─ Now reflects AWS reality
  ├─ Ready for next push
  └─ Cycle repeats...

Example State File:
  {
    "resources": [
      {
        "type": "aws_lambda_function",
        "name": "ray_converter",
        "instances": [{
          "attributes": {
            "function_name": "ray-converter",
            "arn": "arn:aws:lambda:us-east-1:...",
            "handler": "handler.lambda_handler",
            "runtime": "python3.11",
            "memory_size": 128,
            "timeout": 30
          }
        }]
      },
      { ... more resources ... }
    ]
  }
```

---

## GitHub Actions Flow Chart

```
PUSH EVENT
    ↓
    ├─→ Webhook to GitHub
    │
    ├─→ Trigger workflow
    │
    ├─→ Start Test Job
    │   ├─→ Checkout code
    │   ├─→ Setup Python 3.11
    │   ├─→ Install dependencies
    │   ├─→ Run pytest
    │   │
    │   ├─ Result: ✅ PASS
    │   └─ Result: ❌ FAIL → STOP (don't build)
    │
    ├─ IF TEST PASSED:
    │
    ├─→ Start Build Job (needs: test)
    │   ├─→ Checkout code
    │   ├─→ Setup Python
    │   ├─→ Install dependencies with -t python/
    │   ├─→ Create build/ directory
    │   ├─→ ZIP functions/ray_converter/
    │   ├─→ Verify build/ray_converter.zip
    │   ├─→ Authenticate AWS
    │   └─→ Deploy with Terraform
    │       ├─→ terraform init
    │       ├─→ terraform plan -out=tfplan
    │       ├─→ terraform apply tfplan
    │       └─→ terraform output
    │
    ├─→ Output Results
    │   ├─→ Lambda Function Name
    │   ├─→ API Gateway Endpoint
    │   └─→ Deployment Status
    │
    ↓
SUCCESS! New code is live in AWS
```

---

## What's SAFE vs DANGEROUS

```
┌─────────────────────────────────────────────────────────────────┐
│                          SAFE                                    │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Update handler.py                                            │
│ ✅ Update tests                                                 │
│ ✅ Update requirements.txt                                      │
│ ✅ Add new infra resources                                      │
│ ✅ Modify Lambda memory/timeout                                 │
│ ✅ Add new CloudWatch alarms                                    │
│ ✅ Enable new triggers                                          │
│ ✅ Push to develop branch (no deploy)                           │
│ ✅ Create pull requests (no deploy until merge)                 │
│                                                                 │
│ WHY: Everything creates/updates. Nothing destroyed.             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        DANGEROUS ⚠️                             │
├─────────────────────────────────────────────────────────────────┤
│ ❌ Delete resource from .tf file then push                      │
│    → That AWS resource gets DESTROYED                           │
│                                                                 │
│ ❌ Run terraform destroy manually                               │
│    → ALL infrastructure deleted!                               │
│                                                                 │
│ ❌ Manually change AWS resources in console                     │
│    → Terraform state gets confused                             │
│    → Next push might overwrite your changes                    │
│                                                                 │
│ ❌ Commit API keys to code                                      │
│    → Available to everyone in git history                      │
│    → Can't delete (git history is permanent)                   │
│                                                                 │
│ ❌ Manual state file edits                                      │
│    → Can corrupt state                                          │
│    → Break next deployments                                    │
│                                                                 │
│ WHY: These bypass Terraform's safety mechanisms                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Emergency Procedures

### If Deployment Breaks Everything

```
SCENARIO: You pushed code and API Gateway got deleted

RECOVERY:
  ┌────────────────────────────────────────────┐
  │ Step 1: Identify the problem               │
  │ Check GitHub Actions logs                  │
  │ See what terraform apply did               │
  └────────────────────────────────────────────┘
         ↓
  ┌────────────────────────────────────────────┐
  │ Step 2: Revert the push                    │
  │ $ git revert HEAD                          │
  │ $ git push origin main                     │
  │                                            │
  │ This creates a NEW commit that undoes     │
  │ the bad changes                            │
  └────────────────────────────────────────────┘
         ↓
  ┌────────────────────────────────────────────┐
  │ Step 3: GitHub Actions redeploys           │
  │ Automatically triggered by git push        │
  │ Terraform restores from state              │
  └────────────────────────────────────────────┘
         ↓
  ┌────────────────────────────────────────────┐
  │ Step 4: Everything back to working state  │
  │ API Gateway restored                       │
  │ Lambda working again                       │
  └────────────────────────────────────────────┘

TIME TO RECOVERY: ~5-10 minutes total
```

---

## Memory Aid Diagram

```
TERRAFORM OPERATION MATRIX:

                ┌────────────────────────────────┐
                │  IS IT IN YOUR CODE?           │
                └────────────────────────────────┘
                        ↙           ↖
                    YES             NO
                    ↙               ↖
         ┌─────────────────┐    ┌─────────────────┐
         │ IS IT IN AWS?   │    │ IS IT IN AWS?   │
         └─────────────────┘    └─────────────────┘
          ↙                  ↖   ↙                 ↖
         YES                 NO YES               NO
         ↙                   ↖  ↙                 ↖
    ┌─────────┐        ┌──────────┐         ┌──────────┐
    │ UPDATE  │        │  CREATE  │         │ DESTROY  │
    │ IF      │        │  RESOURCE│         │ RESOURCE │
    │CHANGED  │        │(NEW)     │         │(DELETE)  │
    └─────────┘        └──────────┘         └──────────┘
```

---

## Key Principles

```
1️⃣  TERRAFORM IS DECLARATIVE
    ├─ You declare desired state
    ├─ Terraform makes reality match
    └─ Not procedural (no "destroy then create")

2️⃣  STATE DRIVES DECISIONS
    ├─ State = "what we think exists"
    ├─ Code = "what should exist"
    ├─ AWS = "what actually exists"
    └─ Terraform: AWS = Code (uses State as memory)

3️⃣  NOTHING DESTROYED BY DEFAULT
    ├─ Only created or updated
    ├─ Removal requires explicit deletion from code
    ├─ Then apply is destructive
    └─ Safety: Remove code → see in terraform plan before apply

4️⃣  IDEMPOTENT OPERATIONS
    ├─ Push same code twice
    ├─ First: creates resources
    ├─ Second: does nothing (already exists)
    ├─ Safe to retry
    └─ Terraform is immune to push duplicates

5️⃣  GITOPS WORKFLOW
    ├─ Source of truth = git repo
    ├─ Push = automatic deployment
    ├─ Revert = automatic rollback
    └─ Everything tracked and auditable
```

---

## Summary

```
✅ SAFE TO PUSH:
   ├─ Any handler.py changes
   ├─ Any test changes
   ├─ Any infra additions
   ├─ Any config changes
   └─ Everything stays running during push

⚠️ BE CAREFUL:
   ├─ Don't manually delete AWS resources
   ├─ Don't mix code and infra commits
   ├─ Don't commit secrets
   └─ Don't edit state file manually

❌ NEVER:
   ├─ Run terraform destroy accidentally
   ├─ Leave failed tests and push
   ├─ Ignore terraform plan warnings
   └─ Edit code in AWS console

🎯 REMEMBER:
   ├─ Push = tests run first
   ├─ If tests pass = deploy
   ├─ Deploy = terraform plan then apply
   ├─ Apply = create/update, never destroy
   ├─ Infrastructure persists between pushes
   └─ You always control destruction
```
