import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import sync_engine

def print_db_url():
    print("\n" + "="*50)
    print("BACKEND IS ACTUALLY CONNECTED TO:")
    print(sync_engine.url)
    print("="*50 + "\n")

if __name__ == "__main__":
    print_db_url()
