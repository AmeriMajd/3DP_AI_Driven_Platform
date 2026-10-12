"""Standalone SMTP smoke test. Run: python smtp_test.py recipient@gmail.com"""
import sys
import smtplib
from email.mime.text import MIMEText
from app.core.config import settings

if len(sys.argv) < 2:
    print("Usage: python smtp_test.py recipient@example.com")
    sys.exit(1)

to_email = sys.argv[1]

print(f"Host={settings.SMTP_HOST} Port={settings.SMTP_PORT} User={settings.SMTP_USER}")
print(f"From={settings.EMAIL_FROM} -> To={to_email}")

msg = MIMEText("SMTP test from 3DP backend")
msg["Subject"] = "SMTP smoke test"
msg["From"] = settings.EMAIL_FROM
msg["To"] = to_email

try:
    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
        server.set_debuglevel(1)
        server.ehlo()
        server.starttls()
        server.login(settings.SMTP_USER, settings.SMTP_PASS)
        server.sendmail(settings.EMAIL_FROM, to_email, msg.as_string())
    print("OK — email accepted by Gmail.")
except Exception as e:
    print(f"FAILED: {type(e).__name__}: {e}")
