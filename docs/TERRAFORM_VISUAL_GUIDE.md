````markdown
# 📊 Visual Guide: Push → Deploy → AWS Flow

## What Happens When You Push Code

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

---

... (rest of file preserved)
````
