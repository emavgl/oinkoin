#!/usr/bin/env python3
"""
Script to create a blog post for a new release on the Oinkoin website.
"""
import os
import sys
from datetime import datetime


def create_blog_post(version_name, changelog_content):
    """
    Create a new blog post for a release in the website/src/content/blog directory.

    Args:
        version_name: The version string (e.g., "2.1.0")
        changelog_content: The content of the changelog
    """
    # Get current date in ISO format
    pub_date = datetime.now().strftime('%Y-%m-%d')

    # Create a slug-friendly filename from the version
    filename = f"release-{version_name.replace('.', '-')}.md"
    blog_dir = "website/src/content/blog"
    filepath = os.path.join(blog_dir, filename)

    # Ensure the blog directory exists
    os.makedirs(blog_dir, exist_ok=True)

    # Format the changelog content with proper markdown
    # Each line starting with "- " is already a list item
    formatted_changelog = changelog_content.strip()

    # Create the blog post content with frontmatter
    blog_content = f"""---
title: 'Release {version_name}'
description: 'Oinkoin version {version_name} is now available with new features and improvements.'
pubDate: {pub_date}
---

We're excited to announce the release of Oinkoin version **{version_name}**! This update brings several improvements and new features to enhance your finance tracking experience.

## What's New

{formatted_changelog}

Thank you for using Oinkoin! If you encounter any issues or have suggestions for future updates, please don't hesitate to reach out through our [GitHub repository](https://github.com/emavgl/oinkoin).
"""

    # Write the blog post file
    with open(filepath, 'w') as f:
        f.write(blog_content)

    print(f'Created blog post at {filepath}')
    return filepath


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python create_release_blog_post.py <version> <changelog_file>")
        sys.exit(1)

    version = sys.argv[1]
    changelog_file = sys.argv[2]

    # Read the changelog content
    with open(changelog_file, 'r') as f:
        changelog_content = f.read()

    create_blog_post(version, changelog_content)

