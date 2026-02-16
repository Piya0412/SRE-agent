"""
API Key retrieval with environment variable fallback for local development.
"""
import os
import logging

# Check for environment variable first (dev mode)
_BACKEND_API_KEY = os.getenv('BACKEND_API_KEY')

if _BACKEND_API_KEY:
    # Dev mode: use environment variable
    def retrieve_api_key(credential_provider_name: str) -> str:
        """Return API key from environment variable."""
        logging.info("🔧 DEV MODE: Using BACKEND_API_KEY environment variable")
        return _BACKEND_API_KEY
else:
    # Production mode: use original implementation
    # (paste original implementation below)
