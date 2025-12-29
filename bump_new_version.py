import re
import sys
import os
import shutil

def update_linux_package_version(new_version_name, config_file_path):
    """Update version in Linux package configuration files"""
    version_pattern = r'version:\s*[\d.]+'

    # Read the config file
    with open(config_file_path, 'r') as config_file:
        config_content = config_file.read()

    # Update the version
    new_config_content = re.sub(version_pattern, f'version: {new_version_name}', config_content)

    # Write back
    with open(config_file_path, 'w') as config_file:
        config_file.write(new_config_content)

    print(f'Updated version to {new_version_name} in {config_file_path}')

def update_flutter_version_and_copy_changelog(new_version_name, changelog_file):
    # Define the regex pattern to match the version line in the pubspec.yaml file
    version_pattern = r'version:\s*([\d.]+)\+(\d+)'

    # Open and read the pubspec.yaml file
    with open('pubspec.yaml', 'r') as pubspec_file:
        pubspec_content = pubspec_file.read()

    matches = re.search(version_pattern, pubspec_content)
    if matches:
        version_name, version_code = matches.groups()
        if new_version_name == "keep":
            new_version_name = version_name
        version_code = int(version_code)
    else:
        print('No version information found in pubspec.yaml')

    # Update the version in pubspec.yaml with the provided version argument
    new_version_code = version_code + 1
    new_pubspec_content = pubspec_content.replace(f"version: {version_name}+{version_code}", f"version: {new_version_name}+{new_version_code}")

    # Write the updated content back to pubspec.yaml
    with open('pubspec.yaml', 'w') as pubspec_file:
        pubspec_file.write(new_pubspec_content)

    print(f'Updated version to {new_version_name} in pubspec.yaml')
    print(f'Incremented version code to {new_version_code}')

    # Update Linux package versions
    linux_deb_config = 'linux/packaging/deb/make_config.yaml'
    linux_rpm_config = 'linux/packaging/rpm/make_config.yaml'
    linux_appimage_config = 'linux/packaging/appimage/make_config.yaml'

    if os.path.exists(linux_deb_config):
        update_linux_package_version(new_version_name, linux_deb_config)
    else:
        print(f'Warning: {linux_deb_config} not found, skipping...')

    if os.path.exists(linux_rpm_config):
        update_linux_package_version(new_version_name, linux_rpm_config)
    else:
        print(f'Warning: {linux_rpm_config} not found, skipping...')

    if os.path.exists(linux_appimage_config):
        update_linux_package_version(new_version_name, linux_appimage_config)
    else:
        print(f'Warning: {linux_appimage_config} not found, skipping...')

    # Copy the changelog file to the specified location (for F-droid)
    changelog_destination = os.path.join('metadata/en-US/changelogs', f'{new_version_code}.txt')
    shutil.copy(changelog_file, changelog_destination)
    print(f'Copied changelog to {changelog_destination}')

    # Copy the changelog file to the specified location (for Github action)
    changelog_destination = os.path.join('metadata/en-US', 'whatsnew-en-US')
    shutil.copy(changelog_file, changelog_destination)
    print(f'Copied changelog to {changelog_destination}')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python update_flutter_version.py <new_version> <changelog_file>")
    else:
        new_version = sys.argv[1]
        changelog_file = sys.argv[2]
        update_flutter_version_and_copy_changelog(new_version, changelog_file)
