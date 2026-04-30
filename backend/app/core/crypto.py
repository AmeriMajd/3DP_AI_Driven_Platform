"""
Symmetric encryption helpers for printer API keys.

Uses Fernet (AES-128-CBC + HMAC) from the `cryptography` package.
The key is read once at import time from settings.PRINTER_ENCRYPTION_KEY.

Generate a key with:
    python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

Then add to backend/.env:
    PRINTER_ENCRYPTION_KEY=<the-generated-key>
"""

from cryptography.fernet import Fernet, InvalidToken

from app.core.config import settings


def _get_fernet() -> Fernet:
    """Build a Fernet instance from the configured key.

    Fails loudly at first call if the key is missing or malformed.
    """
    key = settings.PRINTER_ENCRYPTION_KEY
    if not key:
        raise RuntimeError(
            "PRINTER_ENCRYPTION_KEY is not set. "
            "Generate one with: "
            'python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"'
        )
    # Fernet expects bytes
    return Fernet(key.encode() if isinstance(key, str) else key)


# Build once — Fernet is thread-safe and cheap to keep around.
_fernet = _get_fernet()


def encrypt_api_key(plaintext: str) -> bytes:
    """Encrypt a plaintext API key. Returns raw bytes suitable for LargeBinary column."""
    if plaintext is None:
        raise ValueError("Cannot encrypt None")
    return _fernet.encrypt(plaintext.encode("utf-8"))


def decrypt_api_key(ciphertext: bytes) -> str:
    """Decrypt bytes from the DB back to the plaintext API key.

    Raises InvalidToken if the ciphertext was tampered with or the key changed.
    """
    if ciphertext is None:
        raise ValueError("Cannot decrypt None")
    try:
        return _fernet.decrypt(ciphertext).decode("utf-8")
    except InvalidToken as e:
        raise RuntimeError(
            "Failed to decrypt printer API key — "
            "PRINTER_ENCRYPTION_KEY may have changed since this value was stored."
        ) from e