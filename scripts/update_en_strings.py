import os
import re
import json

# Define a function to search for '.i18n' strings in a file
def extract_i18n_strings(file_path):
    i18n_strings = set()  # Use a set to avoid duplicate strings

    # Regular expression to find strings ending with `.i18n`
    i18n_pattern = re.compile(r"\$?.*(['\"])(.*?)(\1)[\n\s\t]*\.i18n", re.MULTILINE)

    # Open the file and read its content
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            content = file.read()
            matches = i18n_pattern.findall(content)
            for match in matches:
                # Append the full string that needs translation
                i18n_strings.add(match[1])
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")

    return i18n_strings

# Define a function to scan directories recursively
def scan_directory_for_i18n(directory):
    i18n_strings = set()

    # Traverse the directory and subdirectories
    for root, dirs, files in os.walk(directory):
        for file in files:
            # Filter file types if needed, e.g., if file.endswith('.dart'):
            file_path = os.path.join(root, file)
            # Extract .i18n strings from the file
            strings_in_file = extract_i18n_strings(file_path)
            i18n_strings.update(strings_in_file)

    return i18n_strings

# Define a function to write the strings to a JSON file
def write_to_json(file_path, i18n_strings):
    # Sort the strings alphabetically
    sorted_strings = sorted(i18n_strings)

    # Create a dictionary with the sorted strings as keys and empty strings as values
    data = {string: string for string in sorted_strings}

    # Write the dictionary to a JSON file
    with open(file_path, 'w', encoding='utf-8') as json_file:
        json.dump(data, json_file, indent=2, ensure_ascii=False)

# Define a function to clean up locale files
def clean_locale_files(directory, reference_file):
    # Load the keys from the reference JSON file
    with open(reference_file, 'r', encoding='utf-8') as ref_file:
        reference_data = json.load(ref_file)
    reference_keys = set(reference_data.keys())

    # Traverse the locale directory
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.json') and file != os.path.basename(reference_file):
                file_path = os.path.join(root, file)
                print(f"\nProcessing file: {file_path}")

                # Load the current locale JSON file
                with open(file_path, 'r', encoding='utf-8') as locale_file:
                    locale_data = json.load(locale_file)

                locale_keys = set(locale_data.keys())

                # Determine which keys to delete
                keys_to_delete = locale_keys - reference_keys

                if keys_to_delete:
                    print("Keys being deleted:")
                    for key in keys_to_delete:
                        print(f" - {key}")

                    # Remove keys that are not in the reference file
                    for key in keys_to_delete:
                        del locale_data[key]

                    # Save the cleaned locale JSON file
                    with open(file_path, 'w', encoding='utf-8') as locale_file:
                        json.dump(locale_data, locale_file, indent=2, ensure_ascii=False)
                else:
                    print("No keys to delete.")

# Define the main function
def main():
    # Specify the directory to scan and the JSON file path
    directory = "lib"  # Modify as needed
    json_file_path = "assets/locales/en_US.json"

    # Get all the strings needing translations
    i18n_strings = scan_directory_for_i18n(directory)

    # Read the existing JSON file to check for missing keys
    existing_data = {}
    if os.path.exists(json_file_path):
        with open(json_file_path, 'r', encoding='utf-8') as json_file:
            existing_data = json.load(json_file)
    existing_keys = set(existing_data.keys())

    # Write the strings to a new JSON file, sorted alphabetically
    write_to_json(json_file_path, i18n_strings)

    # Load the newly written JSON file
    new_data = {}
    with open(json_file_path, 'r', encoding='utf-8') as json_file:
        new_data = json.load(json_file)
    new_keys = set(new_data.keys())

    # Determine missing and added keys
    missing_keys = existing_keys - new_keys
    added_keys = new_keys - existing_keys

    if missing_keys:
        print("Keys missing in the new JSON file:")
        for key in missing_keys:
            print(f" - {key}")

    if added_keys:
        print("Keys added in the new JSON file:")
        for key in added_keys:
            print(f" - {key}")

    if i18n_strings:
        print(f"\nFound {len(i18n_strings)} unique translation strings in total.")
        print(f"Strings written to {json_file_path}")

        # Clean up other locale files
        locale_directory = "assets/locales/"
        clean_locale_files(locale_directory, json_file_path)
    else:
        print("No .i18n strings found.")

if __name__ == "__main__":
    main()
