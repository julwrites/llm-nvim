import os
import tempfile
import json
import time
import gzip

def write_atomic(filepath, content, mode='w', encoding='utf-8'):
    """
    Writes content to a file atomically.
    1. Writes to a temporary file in the same directory.
    2. Flushes and fsyncs.
    3. Renames the temporary file to the target filepath.
    """
    directory = os.path.dirname(os.path.abspath(filepath))
    if not os.path.exists(directory):
        os.makedirs(directory, exist_ok=True)

    # Create temp file in same directory to ensure atomic rename
    # mkstemp returns a low-level file handle (int) and the absolute path
    fd, tmp_path = tempfile.mkstemp(dir=directory, text=(mode == 'w'))

    try:
        with os.fdopen(fd, mode, encoding=encoding if mode == 'w' else None) as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())

        # Atomic rename
        os.replace(tmp_path, filepath)
    except Exception as e:
        # Cleanup temp file on failure
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise e

def write_atomic_gzip(filepath, content_str, encoding='utf-8'):
    """Atomic write for GZIP files."""
    directory = os.path.dirname(os.path.abspath(filepath))
    if not os.path.exists(directory):
        os.makedirs(directory, exist_ok=True)

    fd, tmp_path = tempfile.mkstemp(dir=directory, suffix='.gz')
    os.close(fd)

    try:
        with gzip.open(tmp_path, 'wt', encoding=encoding) as f:
            f.write(content_str)
            f.flush()
            # Try to fsync underlying file
            if hasattr(f, 'fileobj') and f.fileobj:
                f.fileobj.flush()
                os.fsync(f.fileobj.fileno())

        os.replace(tmp_path, filepath)
    except Exception as e:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise e

def read_text(filepath, encoding='utf-8', retries=3, delay=0.1):
    """
    Reads text from a file with simple retry logic for transient errors.
    Supports .gz files transparently.
    """
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"File not found: {filepath}")

    is_gzip = filepath.endswith('.gz')

    for attempt in range(retries):
        try:
            if is_gzip:
                with gzip.open(filepath, 'rt', encoding=encoding) as f:
                    return f.read()
            else:
                with open(filepath, 'r', encoding=encoding) as f:
                    return f.read()
        except OSError:
            if attempt == retries - 1:
                raise
            time.sleep(delay)

def write_json(filepath, data, indent=2):
    """Atomic write for JSON (supports .gz)."""
    content = json.dumps(data, indent=indent, sort_keys=True)
    if filepath.endswith('.gz'):
        write_atomic_gzip(filepath, content)
    else:
        write_atomic(filepath, content + "\n")

def read_json(filepath):
    """Read JSON from file (supports .gz)."""
    content = read_text(filepath)
    return json.loads(content)