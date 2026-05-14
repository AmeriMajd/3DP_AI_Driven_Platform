import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config import settings


def send_password_reset_email(to_email: str, reset_token: str) -> bool:

    reset_link = f"{settings.APP_BASE_URL}/reset-password?token={reset_token}"

    plain_text = f"""
3DP Intelligence Platform — Password Reset

Hi,

We received a request to reset the password for your account ({to_email}).

Reset your password here (valid for 1 hour):
{reset_link}

If you didn't request this, you can safely ignore this email.
Your password will not change until you click the link above.

— 3DP Intelligence Platform Team
    """.strip()

    html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0; padding:0; background-color:#f0f4f8; font-family:'Segoe UI', Arial, sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f0f4f8; padding:40px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px; width:100%;">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #0f2444 0%, #1a3a6b 100%);
                        border-radius:12px 12px 0 0; padding:36px 40px; text-align:center;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <div style="display:inline-block; background:rgba(255,255,255,0.12);
                                border-radius:12px; padding:10px 18px; margin-bottom:14px;">
                      <span style="color:#60a5fa; font-size:22px; font-weight:800;
                                   letter-spacing:1px;">3DP</span>
                      <span style="color:#ffffff; font-size:22px; font-weight:300;
                                   letter-spacing:1px;"> Intelligence</span>
                    </div>
                    <br>
                    <span style="color:rgba(255,255,255,0.6); font-size:13px;
                                 letter-spacing:2px; text-transform:uppercase;">
                      Platform
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="background:#ffffff; padding:48px 40px 36px 40px;">

              <!-- Icon -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding-bottom:28px;">
                    <div style="width:64px; height:64px; background:#eff6ff;
                                border-radius:50%; display:inline-block;
                                line-height:64px; text-align:center; font-size:28px;">
                      🔐
                    </div>
                  </td>
                </tr>
              </table>

              <h1 style="margin:0 0 12px 0; font-size:24px; font-weight:700;
                          color:#0f2444; text-align:center; letter-spacing:-0.3px;">
                Reset your password
              </h1>

              <p style="margin:0 0 8px 0; font-size:15px; color:#64748b;
                         text-align:center; line-height:1.6;">
                We received a request to reset the password for
              </p>
              <p style="margin:0 0 32px 0; font-size:15px; color:#1a3a6b;
                         text-align:center; font-weight:600;">
                {to_email}
              </p>

              <!-- Button -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
                <tr>
                  <td align="center">
                    <a href="{reset_link}"
                       style="display:inline-block; padding:16px 40px;
                              background: linear-gradient(135deg, #1a3a6b 0%, #2563eb 100%);
                              color:#ffffff; text-decoration:none; border-radius:8px;
                              font-size:16px; font-weight:600; letter-spacing:0.3px;
                              box-shadow:0 4px 14px rgba(37,99,235,0.35);">
                      Reset Password
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Expiry notice -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
                <tr>
                  <td style="background:#fafafa; border:1px solid #e2e8f0;
                              border-radius:8px; padding:16px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td width="20" style="vertical-align:top; padding-top:1px;">
                          <span style="color:#f59e0b; font-size:16px;">⏱</span>
                        </td>
                        <td style="padding-left:10px;">
                          <span style="font-size:13px; color:#475569; line-height:1.5;">
                            This link expires in <strong style="color:#0f2444;">1 hour</strong>.
                            After that you'll need to request a new one.
                          </span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Divider -->
              <hr style="border:none; border-top:1px solid #e2e8f0; margin:0 0 24px 0;">

              <!-- Security notice -->
              <p style="margin:0; font-size:13px; color:#94a3b8;
                         text-align:center; line-height:1.6;">
                Didn't request a password reset?<br>
                You can safely ignore this email — your password won't change.
              </p>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#f8fafc; border-top:1px solid #e2e8f0;
                        border-radius:0 0 12px 12px; padding:24px 40px; text-align:center;">
              <p style="margin:0 0 6px 0; font-size:12px; color:#94a3b8;">
                © 2026 3DP Intelligence Platform. All rights reserved.
              </p>
              <p style="margin:0; font-size:11px; color:#cbd5e1;">
                This is an automated message — please do not reply.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>

</body>
</html>
    """

    message = MIMEMultipart("alternative")
    message["Subject"] = "Reset your 3DP Platform password"
    message["From"] = settings.EMAIL_FROM
    message["To"] = to_email

    message.attach(MIMEText(plain_text, "plain"))
    message.attach(MIMEText(html_content, "html"))

    try:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASS)
            server.sendmail(
                settings.EMAIL_FROM,
                to_email,
                message.as_string()
            )
        return True

    except Exception as e:
        print(f"[EMAIL ERROR] Failed to send reset email to {to_email}: {e}")
        return False


def send_invitation_email(
    to_email: str,
    token: str,
    role: str,
    inviter_name: str | None = None,
) -> bool:
    print(f"[EMAIL] send_invitation_email -> {to_email} via {settings.SMTP_HOST}", flush=True)
    invite_link = f"{settings.APP_BASE_URL}/register?token={token}"
    inviter_line = (
        f"{inviter_name} has invited you" if inviter_name else "You have been invited"
    )

    plain_text = f"""
3DP Intelligence Platform — Invitation

Hi,

{inviter_line} to join the 3DP Intelligence Platform as a {role}.

Accept your invitation here (valid for 48 hours):
{invite_link}

If you weren't expecting this, you can safely ignore this email.

— 3DP Intelligence Platform Team
    """.strip()

    html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0; padding:0; background-color:#f0f4f8; font-family:'Segoe UI', Arial, sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f0f4f8; padding:40px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px; width:100%;">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #0f2444 0%, #1a3a6b 100%);
                        border-radius:12px 12px 0 0; padding:36px 40px; text-align:center;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <div style="display:inline-block; background:rgba(255,255,255,0.12);
                                border-radius:12px; padding:10px 18px; margin-bottom:14px;">
                      <span style="color:#60a5fa; font-size:22px; font-weight:800;
                                   letter-spacing:1px;">3DP</span>
                      <span style="color:#ffffff; font-size:22px; font-weight:300;
                                   letter-spacing:1px;"> Intelligence</span>
                    </div>
                    <br>
                    <span style="color:rgba(255,255,255,0.6); font-size:13px;
                                 letter-spacing:2px; text-transform:uppercase;">
                      Platform
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="background:#ffffff; padding:48px 40px 36px 40px;">

              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding-bottom:28px;">
                    <div style="width:64px; height:64px; background:#eff6ff;
                                border-radius:50%; display:inline-block;
                                line-height:64px; text-align:center; font-size:28px;">
                      ✉️
                    </div>
                  </td>
                </tr>
              </table>

              <h1 style="margin:0 0 12px 0; font-size:24px; font-weight:700;
                          color:#0f2444; text-align:center; letter-spacing:-0.3px;">
                You've been invited
              </h1>

              <p style="margin:0 0 8px 0; font-size:15px; color:#64748b;
                         text-align:center; line-height:1.6;">
                {inviter_line} to join as
              </p>
              <p style="margin:0 0 32px 0; font-size:15px; color:#1a3a6b;
                         text-align:center; font-weight:600; text-transform:capitalize;">
                {role}
              </p>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
                <tr>
                  <td align="center">
                    <a href="{invite_link}"
                       style="display:inline-block; padding:16px 40px;
                              background: linear-gradient(135deg, #1a3a6b 0%, #2563eb 100%);
                              color:#ffffff; text-decoration:none; border-radius:8px;
                              font-size:16px; font-weight:600; letter-spacing:0.3px;
                              box-shadow:0 4px 14px rgba(37,99,235,0.35);">
                      Accept Invitation
                    </a>
                  </td>
                </tr>
              </table>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
                <tr>
                  <td style="background:#fafafa; border:1px solid #e2e8f0;
                              border-radius:8px; padding:16px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td width="20" style="vertical-align:top; padding-top:1px;">
                          <span style="color:#f59e0b; font-size:16px;">⏱</span>
                        </td>
                        <td style="padding-left:10px;">
                          <span style="font-size:13px; color:#475569; line-height:1.5;">
                            This invitation expires in <strong style="color:#0f2444;">48 hours</strong>.
                          </span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <hr style="border:none; border-top:1px solid #e2e8f0; margin:0 0 24px 0;">

              <p style="margin:0; font-size:13px; color:#94a3b8;
                         text-align:center; line-height:1.6;">
                Weren't expecting this invitation?<br>
                You can safely ignore this email.
              </p>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#f8fafc; border-top:1px solid #e2e8f0;
                        border-radius:0 0 12px 12px; padding:24px 40px; text-align:center;">
              <p style="margin:0 0 6px 0; font-size:12px; color:#94a3b8;">
                © 2026 3DP Intelligence Platform. All rights reserved.
              </p>
              <p style="margin:0; font-size:11px; color:#cbd5e1;">
                This is an automated message — please do not reply.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>

</body>
</html>
    """

    message = MIMEMultipart("alternative")
    message["Subject"] = "You've been invited to 3DP Intelligence Platform"
    message["From"] = settings.EMAIL_FROM
    message["To"] = to_email

    message.attach(MIMEText(plain_text, "plain"))
    message.attach(MIMEText(html_content, "html"))

    try:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASS)
            server.sendmail(
                settings.EMAIL_FROM,
                to_email,
                message.as_string()
            )
        return True

    except Exception as e:
        print(f"[EMAIL ERROR] Failed to send invitation email to {to_email}: {e}")
        return False
