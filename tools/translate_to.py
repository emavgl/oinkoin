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

def ask_for_missing_translations(file_path, entries, language, dry_run = False):
    entries_with_missing_translation = [entry for entry in entries if language not in entry]
    if entries_with_missing_translation:
        print("\nMissing translation in file", file_path)
        for missing_entry in entries_with_missing_translation:
            original_sentence = missing_entry['en_us']
            if dry_run:
                print(f"[{language}] translation for '{original_sentence}'")
            else:
                prompt = f"Enter the [{language}] translation for '{original_sentence}': "
                translation = input(prompt)
                if translation:
                    missing_entry[language] = translation
                    save(file_path, entries)
                else:
                    print("No translation provided, skipping")
    if not dry_run:
        save(file_path, entries)

def save(file_path, entries):
    destination_file_path = file_path.replace(".dart", ".json")
    with open(destination_file_path, 'w') as destination_file:
        json.dump(entries, destination_file, indent=4)

def main(language, dry_run = False):
    root_folder = './lib'
    i18n_files = find_i18n_files(root_folder)
    for file_path in i18n_files:
        entries = extract_entries(file_path)
        if not entries:
            print("Could not extract entries from: ", file_path)
        ask_for_missing_translations(file_path, entries, language, dry_run)

if __name__ == "__main__":

    if len(sys.argv) != 3:
        print("Usage: python to_translate.py <option> <language>")
        sys.exit(1)

    dry_run = False if sys.argv[1] == 'translate' else True
    language = sys.argv[2]
    main(language, dry_run)