#!/usr/bin/env bash --posix
USAGE_MARKDOWN=../USAGE.md

function append {
  echo "$@" >> $USAGE_MARKDOWN
}

function addUsage {
  local command="$@"
  append
  append "## cm $command"
  append '```'
  append "$(../cm -h $@ 2>&1)"
  append '```'
  append "<sup><sub>[🔝 Back to top](#usage)</sub></sup>"
}

echo "# Usage" > $USAGE_MARKDOWN
append "### Index"
append "* [cm](#cm)"

SUBCOMMANDS=$(ls ../subcommands)
for subcommand in $SUBCOMMANDS
do
  name=$(basename $subcommand .sh)
  append "  * [${name}](#cm-${name})" 
done

append "### Commands"

addUsage

SUBCOMMANDS=$(ls ../subcommands)
for subcommand in $SUBCOMMANDS
do
  addUsage $(basename $subcommand .sh)
done
