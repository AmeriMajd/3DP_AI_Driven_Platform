import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config import settings


def send_password_reset_email(to_email: str, reset_token: str) -> bool:

    reset_link = f"{settings.APP_BASE_URL}/reset-password?token={reset_token}"

    message = MIMEMultipart("alternative")
    message["Subject"] = "3DP Platform — Reset your password"
    message["From"] = settings.SMTP_FROM
    message["To"] = to_email

    plain_text = f"""
Hello,

You requested a password reset for your 3DP Intelligence Platform account.

Click the link below to reset your password (valid for 1 hour) :
{reset_link}

If you did not request this, ignore this email.

3DP Intelligence Platform Team
    """.strip()

    html_content = f"""
    <html>
      <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #1E3A5F;">3DP Intelligence Platform</h2>
        <p>You requested a password reset for your account.</p>
        <p>This link expires in <strong>1 hour</strong>.</p>
        <a href="{reset_link}"
           style="display:inline-block; padding:12px 24px; background:#2E6DA4;
                  color:white; text-decoration:none; border-radius:4px; margin:16px 0;">
          Reset Password
        </a>
        <p style="color:#888; font-size:12px;">
          If you did not request this, ignore this email.<br>
          Link: {reset_link}
        </p>
      </body>
    </html>
    """

    message.attach(MIMEText(plain_text, "plain"))
    message.attach(MIMEText(html_content, "html"))

    try:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASS)
            server.sendmail(
                settings.SMTP_FROM,
                to_email,
                message.as_string()
            )
        return True

    except Exception as e:
        print(f"[EMAIL ERROR] Failed to send reset email to {to_email}: {e}")
        return False