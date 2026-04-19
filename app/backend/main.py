# app/backend/main.py
import os
from app import create_app
from load_azd_env import load_azd_env

try:
    # Attempt to load, but don't kill the app if it fails
    load_azd_env()
except Exception as e:
    print(f"Skipping azd env load (likely running in Azure): {e}")

app = create_app()