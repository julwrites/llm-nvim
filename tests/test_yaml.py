import unittest
import os
import shutil
from scripts.lib import yaml

class TestSimpleYaml(unittest.TestCase):
    def setUp(self):
        self.test_dir = "tests/tmp_yaml"
        os.makedirs(self.test_dir, exist_ok=True)
        self.filepath = os.path.join(self.test_dir, "test.yaml")

    def tearDown(self):
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_load_config_structure(self):
        content = """
project:
  name: MyProject
  root: .

tasks:
  categories:
    - foundation
    - features
  statuses:
    - pending
    - done

agents:
  audit_log: logs/audit.jsonl
"""
        with open(self.filepath, "w") as f:
            f.write(content)

        data = yaml.SimpleYaml.load(self.filepath)

        self.assertEqual(data["project"]["name"], "MyProject")
        self.assertEqual(data["tasks"]["categories"], ["foundation", "features"])
        self.assertEqual(data["tasks"]["statuses"], ["pending", "done"])
        self.assertEqual(data["agents"]["audit_log"], "logs/audit.jsonl")

    def test_save_config_structure(self):
        data = {
            "project": {"name": "Test"},
            "tasks": {"list": ["a", "b"]}
        }
        yaml.SimpleYaml.save(self.filepath, data)

        loaded = yaml.SimpleYaml.load(self.filepath)
        self.assertEqual(loaded, data)

if __name__ == '__main__':
    unittest.main()
