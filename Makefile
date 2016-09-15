.PHONY: serve deploy

help: ## Show this help
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

deploy: ## Deploy to GitHub Pages
	echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

	# Build the project.
	hugo -d docs
	echo "blog.fntlnz.wtf" > docs/CNAME

	# Add changes to git.
	git add -A

	# Commit changes.
	git commit -m "rebuilding site `date`"

	# Deploy	
	git push origin master

serve: ## Serve a local development copy
	hugo serve
