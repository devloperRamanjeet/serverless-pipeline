# ❓ What Happens When You Push Code? - Terraform Behavior Explained

## TL;DR - Quick Answer

**When you push code to GitHub:**
- ✅ Terraform **ONLY creates new resources** if they don't exist
- ✅ Terraform **ONLY updates resources** if code changed
- ✅ Terraform **leaves unchanged resources alone** (no disruption)
- ❌ Terraform **NEVER destroys** infrastructure on push
- ❌ You must **manually run** `terraform destroy` to delete resources

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

... (rest of file preserved)
