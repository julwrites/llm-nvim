import os

class SimpleYaml:
    """
    A simple, dependency-free YAML parser/dumper.
    Optimized for the project's config schema (max 2 levels of nesting + lists).
    """

    @staticmethod
    def load(filepath):
        if not os.path.exists(filepath):
            return {}

        with open(filepath, 'r') as f:
            lines = f.readlines()

        return SimpleYaml._parse(lines)

    @staticmethod
    def _parse(lines):
        data = {}
        current_section = None # Top level key
        current_subsection = None # Second level key (if it holds a list)

        def clean(v):
            v = v.strip()
            if (v.startswith('"') and v.endswith('"')) or (v.startswith("'" ) and v.endswith("'")):
                return v[1:-1]
            return v

        for line in lines:
            line_content = line.strip()
            if not line_content or line_content.startswith('#'):
                continue

            indent = len(line) - len(line.lstrip())

            if indent == 0:
                if ':' in line_content:
                    key = line_content.split(':', 1)[0].strip()
                    data[key] = {}
                    current_section = key
                    current_subsection = None

            elif indent == 2 and current_section:
                if line_content.startswith('- '):
                    # List under section
                    if isinstance(data[current_section], dict) and not data[current_section]:
                         data[current_section] = []

                    if isinstance(data[current_section], list):
                        data[current_section].append(clean(line_content[2:]))

                elif ':' in line_content:
                    parts = line_content.split(':', 1)
                    key = parts[0].strip()
                    val = parts[1].strip()

                    if val:
                        # Key: Value
                        data[current_section][key] = clean(val)
                    else:
                        # Key: ... (implies list or dict following)
                        # For our config, it's usually a list
                        data[current_section][key] = []
                        current_subsection = key

            elif indent >= 4 and current_section and current_subsection:
                 if line_content.startswith('- '):
                     # List item under subsection
                     if isinstance(data[current_section][current_subsection], list):
                         data[current_section][current_subsection].append(clean(line_content[2:]))

        return data

    @staticmethod
    def save(filepath, data):
        with open(filepath, 'w') as f:
            for key, val in data.items():
                f.write(f"{key}:\n")
                if isinstance(val, dict):
                    for subkey, subval in val.items():
                        if isinstance(subval, list):
                            f.write(f"  {subkey}:\n")
                            for item in subval:
                                f.write(f"    - {item}\n")
                        else:
                            f.write(f"  {subkey}: {subval}\n")
                elif isinstance(val, list):
                    for item in val:
                        f.write(f"  - {item}\n")
                f.write("\n")