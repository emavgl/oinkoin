import sys
import re
import os
import json
from collections import OrderedDict

def extract_entries(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

        pattern = r'"(\w+)":\s*"(.+)"'
        matches = re.findall(pattern, content, re.MULTILINE | re.IGNORECASE | re.UNICODE)

        entries = []
        new_entry = None

        for match in matches:
            language, translation = match
            if language == "en_us":
                if new_entry:
                    entries.append(new_entry)
                new_entry = OrderedDict()
            new_entry[language] = translation
        
        return entries
        
def find_i18n_files(root_folder):
    i18n_files = []
    for foldername, subfolders, filenames in os.walk(root_folder):
        for filename in filenames:
            if filename.endswith('.i18n.dart'):
                i18n_files.append(os.path.join(foldername, filename))
    return i18n_files

def save(file_path, entries):
    destination_file_path = file_path.replace(".dart", ".json")
    with open(destination_file_path, 'w') as destination_file:
        json.dump(entries, destination_file, indent=4)

def save_to_json(files_and_entries, total_entries):
    # use as set
    global_entries_per_language = {
        "en": {},
        "it": {}
    }
    for entry in total_entries:
        entry_key = entry['en_us']
        global_entries_per_language['en'][entry_key] = entry_key
        global_entries_per_language['it'][entry_key] = entry['it_it']

    with open("en.json", 'w') as destination_file:
        json.dump(global_entries_per_language['en'], destination_file, indent=4)
        
    with open("it.json", 'w') as destination_file:
        json.dump(global_entries_per_language['it'], destination_file, indent=4)

def main():
    root_folder = './lib'
    i18n_files = find_i18n_files(root_folder)
    file_and_entries = []
    total_entries = []
    for file_path in i18n_files:
        entries = extract_entries(file_path)
        if not entries:
            print("Could not extract entries from: ", file_path)
        file_and_entries.append({
            'file_path': file_path,
            'entries': entries
        })
        total_entries += entries
    save_to_json(file_and_entries, total_entries)

if __name__ == "__main__":
    main()