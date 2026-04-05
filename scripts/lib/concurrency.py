import os
import time
import fcntl
import errno
from contextlib import contextmanager

class FileLockException(Exception):
    pass

class FileLock:
    """
    A file locking mechanism using fcntl.flock for POSIX systems.
    """
    def __init__(self, lock_file, timeout=5, delay=0.1):
        self.lock_file = lock_file
        self.timeout = timeout
        self.delay = delay
        self.fd = None

    def acquire(self):
        start_time = time.time()
        # Ensure directory exists
        os.makedirs(os.path.dirname(os.path.abspath(self.lock_file)), exist_ok=True)

        self.fd = open(self.lock_file, 'w')

        while True:
            try:
                # LOCK_EX: Exclusive lock
                # LOCK_NB: Non-blocking
                fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return
            except (IOError, OSError) as e:
                if e.errno != errno.EAGAIN:
                    raise
                if (time.time() - start_time) >= self.timeout:
                    self.fd.close()
                    raise FileLockException(f"Could not acquire lock on {self.lock_file} within {self.timeout}s")
                time.sleep(self.delay)

    def release(self):
        if self.fd:
            try:
                fcntl.flock(self.fd, fcntl.LOCK_UN)
            except:
                pass
            self.fd.close()
            self.fd = None

    def __enter__(self):
        self.acquire()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.release()
