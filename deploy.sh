#!/usr/bin/env bash

echo -e "\033[0;32mDeploying updates to Github...\033[0m"
git subtree push --prefix=public git@github.com:fntlnz/blog.fntlnz.wtf.git gh-pages
