# assets

Put the corporate template here as `template.pptx`, stripped of its slides so
only the master and layouts remain. The stripping snippet is in `../SKILL.md`
under "Adapting this skill".

No template is committed, for two reasons. A corporate template is usually not
redistributable, and a sample that ships one invites people to build decks that
follow somebody else's brand. When `--template` is omitted, `build_deck.py`
falls back to a neutral template so the skill runs unchanged.

Fonts belong here too when the template depends on one that is not present in
the runtime. Reference them from a custom container image rather than expecting
the base environment to have them; see the repository README.
