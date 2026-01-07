# Email Notifications Setup Guide

This guide explains how to configure email notifications for the Disconnected Resources Pipeline.

## Overview

When enabled, the pipeline will send formatted HTML email notifications to specified recipients when:
- ✅ A bundle is successfully generated (with summary statistics)
- ❌ A bundle generation fails (with error details and troubleshooting steps)

## Configuration

### Step 1: Configure Email Recipients

Edit `resources-config.yaml` to enable email notifications:

```yaml
notifications:
  email:
    enabled: true
    recipients:
      - "user1@example.com"
      - "user2@example.com"
      - "team@example.com"
    send_on_success: true
    send_on_failure: true
    include_summary: true
```

**Options:**
- `enabled`: Set to `true` to enable email notifications
- `recipients`: List of email addresses to receive notifications
- `send_on_success`: Send email when bundle is successfully generated
- `send_on_failure`: Send email when bundle generation fails
- `include_summary`: Include detailed statistics in the email (currently always included)

### Step 2: Configure SMTP Secrets

You need to configure SMTP server credentials as GitHub Secrets.

#### Add GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SMTP_SERVER` | SMTP server address | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP server port | `587` (TLS) or `465` (SSL) |
| `SMTP_USERNAME` | SMTP username | `your-email@gmail.com` |
| `SMTP_PASSWORD` | SMTP password or app password | `your-app-password` |
| `SMTP_FROM_EMAIL` | Sender email address | `noreply@example.com` |

## SMTP Provider Setup

### Gmail

**Requirements:**
- Gmail account with 2-factor authentication enabled
- App-specific password

**Steps:**
1. Enable 2-factor authentication on your Google account
2. Generate an app password:
   - Go to: https://myaccount.google.com/apppasswords
   - Select "Mail" and "Other (Custom name)"
   - Name it "GitHub Actions"
   - Copy the 16-character password

**GitHub Secrets:**
```
SMTP_SERVER: smtp.gmail.com
SMTP_PORT: 587
SMTP_USERNAME: your-email@gmail.com
SMTP_PASSWORD: your-16-char-app-password
SMTP_FROM_EMAIL: your-email@gmail.com
```

### Microsoft 365 / Outlook

**GitHub Secrets:**
```
SMTP_SERVER: smtp.office365.com
SMTP_PORT: 587
SMTP_USERNAME: your-email@outlook.com
SMTP_PASSWORD: your-password
SMTP_FROM_EMAIL: your-email@outlook.com
```

### SendGrid

**Requirements:**
- SendGrid account
- API Key

**Steps:**
1. Create SendGrid account at https://sendgrid.com
2. Generate an API Key:
   - Go to Settings → API Keys
   - Create API Key with "Mail Send" permission
   - Copy the API Key

**GitHub Secrets:**
```
SMTP_SERVER: smtp.sendgrid.net
SMTP_PORT: 587
SMTP_USERNAME: apikey
SMTP_PASSWORD: your-sendgrid-api-key
SMTP_FROM_EMAIL: verified-sender@yourdomain.com
```

**Note:** Sender email must be verified in SendGrid

### AWS SES (Simple Email Service)

**Requirements:**
- AWS account
- SES SMTP credentials
- Verified email address/domain

**Steps:**
1. Set up SES in AWS Console
2. Verify your sender email or domain
3. Create SMTP credentials in SES console
4. Note your SMTP endpoint (region-specific)

**GitHub Secrets:**
```
SMTP_SERVER: email-smtp.us-east-1.amazonaws.com
SMTP_PORT: 587
SMTP_USERNAME: your-ses-smtp-username
SMTP_PASSWORD: your-ses-smtp-password
SMTP_FROM_EMAIL: verified@yourdomain.com
```

### Custom SMTP Server

If you have your own SMTP server:

**GitHub Secrets:**
```
SMTP_SERVER: mail.yourdomain.com
SMTP_PORT: 587
SMTP_USERNAME: smtp-username
SMTP_PASSWORD: smtp-password
SMTP_FROM_EMAIL: noreply@yourdomain.com
```

## Email Content

### Success Email

When a bundle is successfully generated, recipients receive an HTML email with:

- **Status**: Visual success indicator
- **Bundle Information**:
  - Environment name
  - Bundle name
  - Generation timestamp
  - Total size
  - Who triggered it
- **Component Statistics**:
  - Count of npm packages
  - Count of PyPI packages
  - Count of Debian packages
  - Count of RPM packages
  - Count of container images
  - Count of VSCode extensions
- **Download Instructions**: Step-by-step guide
- **Direct Link**: Button to view the workflow run
- **Important Notes**: Reminders about checksums and retention

### Failure Email

When bundle generation fails, recipients receive an HTML email with:

- **Status**: Visual error indicator
- **Error Details**:
  - Environment name
  - Timestamp
  - Who triggered it
- **Next Steps**: Troubleshooting guidance
- **Direct Link**: Button to view workflow logs

## Testing Email Notifications

### Test with Manual Workflow Run

1. Configure email settings in `resources-config.yaml`
2. Add SMTP secrets to GitHub
3. Manually trigger the workflow:
   - Go to **Actions** tab
   - Select "Generate Disconnected Resources Bundle"
   - Click **Run workflow**
4. Wait for completion
5. Check your email inbox

### Test Email Recipients

Start with a test email address before adding all recipients:

```yaml
notifications:
  email:
    enabled: true
    recipients:
      - "test@example.com"  # Test with one email first
    send_on_success: true
    send_on_failure: true
```

## Troubleshooting

### Email Not Received

**Check spam folder:**
- Email might be filtered as spam
- Add sender to whitelist

**Verify GitHub Secrets:**
- Ensure all SMTP secrets are correctly set
- Secret names must match exactly (case-sensitive)
- No extra spaces in secret values

**Check workflow logs:**
- Go to Actions tab → Failed workflow
- Expand "Send email notification" step
- Look for error messages

**Common errors:**
- `535 Authentication failed`: Wrong username/password
- `Connection refused`: Wrong SMTP server or port
- `Sender not verified`: Email address not verified with provider
- `Rate limit exceeded`: Too many emails sent

### Testing SMTP Credentials

Test your SMTP credentials locally before adding to GitHub:

```bash
# Using Python
python3 << 'EOF'
import smtplib
from email.mime.text import MIMEText

smtp_server = "smtp.gmail.com"
smtp_port = 587
username = "your-email@gmail.com"
password = "your-password"

msg = MIMEText("Test email")
msg['Subject'] = "Test"
msg['From'] = username
msg['To'] = "recipient@example.com"

with smtplib.SMTP(smtp_server, smtp_port) as server:
    server.starttls()
    server.login(username, password)
    server.send_message(msg)
    print("Email sent successfully!")
EOF
```

### Email Formatting Issues

If email appears broken:
- Some email clients may not support HTML
- Check email source/raw view
- Ensure SMTP provider allows HTML emails

### Disabling Email Notifications

To temporarily disable emails without removing configuration:

```yaml
notifications:
  email:
    enabled: false  # Set to false
```

Or remove the `notifications` section entirely.

## Security Best Practices

1. **Use App Passwords**: For Gmail/Outlook, use app-specific passwords instead of account passwords
2. **Least Privilege**: Create dedicated email accounts for automation
3. **Rotate Credentials**: Periodically update SMTP passwords
4. **Monitor Usage**: Watch for unusual email activity
5. **Limit Recipients**: Only add necessary recipients
6. **Secure Secrets**: Never commit secrets to git

## Advanced Configuration

### Dynamic Recipients

You can use different configurations for different environments:

```yaml
# resources-config-prod.yaml
notifications:
  email:
    recipients:
      - "prod-team@example.com"

# resources-config-dev.yaml
notifications:
  email:
    recipients:
      - "dev-team@example.com"
```

### Custom Email Templates

The email templates are defined in the workflow file. To customize:

1. Edit `.github/workflows/generate-resources.yml`
2. Find the "Prepare email content" step
3. Modify the HTML in the `cat > email_body.html << EOF` sections
4. Test changes with a workflow run

### Adding Attachments

The current implementation doesn't support attachments (bundles are too large). Recipients download artifacts from GitHub Actions.

To add small attachments, modify the email action step:

```yaml
- name: Send success email notification
  uses: dawidd6/action-send-mail@v3
  with:
    # ... existing config ...
    attachments: path/to/small-file.txt
```

## Email Action Documentation

This pipeline uses the `dawidd6/action-send-mail` GitHub Action.

For more details: https://github.com/dawidd6/action-send-mail

## Support

If you encounter issues with email notifications:

1. Review this guide
2. Check GitHub Actions logs
3. Verify SMTP credentials
4. Test with a simple email client first
5. Check your email provider's documentation

## Alternative Notification Methods

If email doesn't work for your organization, consider:

- **Slack**: Use Slack webhook actions
- **Microsoft Teams**: Use Teams webhook actions
- **Discord**: Use Discord webhook actions
- **Custom Webhooks**: Call your own notification service
- **GitHub Notifications**: Enable GitHub watch notifications

Each alternative would require modifying the workflow to use different notification actions.
