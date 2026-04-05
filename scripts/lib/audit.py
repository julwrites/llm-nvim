import os
import json
import datetime
from scripts.lib import io

def log_activity(action, args=None, agent_id=None, result="success"):
    """
    Appends a structured log entry to the agent audit log.
    """
    # Get configuration
    # Note: repo_root calculation logic copied from other scripts
    script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    repo_root = os.getenv("TASKS_REPO_ROOT", os.path.dirname(script_dir))

    # conf = config.get_config(repo_root)
    # log_path = os.path.join(repo_root, conf["agents"]["audit_log"])
    log_path = os.path.join(repo_root, "logs", "audit.log")

    # Ensure logs directory exists
    log_dir = os.path.dirname(log_path)
    if not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)

    entry = {
        "timestamp": datetime.datetime.now().isoformat(),
        "agent_id": agent_id or os.getenv("AGENT_ID", "human-or-unknown"),
        "action": action,
        "args": args or {},
        "result": result
    }

    # Helper for JSON serialization of complex objects
    def serialize(obj):
        try:
            return json.dumps(obj)
        except (TypeError, OverflowError):
            return str(obj)

    # Append to JSONL file
    try:
        safe_json = json.dumps(entry, default=lambda o: str(o))
        with open(log_path, "a") as f:
            f.write(safe_json + "\n")
    except Exception as e:
        print(f"Warning: Failed to write to audit log: {e}")

def audit_log(action):
    """
    Decorator for simple function auditing.
    """
    def decorator(func):
        def wrapper(*args, **kwargs):
            try:
                res = func(*args, **kwargs)
                log_activity(action, {"args": list(args), "kwargs": kwargs}, result="success")
                return res
            except Exception as e:
                log_activity(action, {"args": list(args), "kwargs": kwargs}, result=f"error: {str(e)}")
                raise e
        return wrapper
    return decorator
