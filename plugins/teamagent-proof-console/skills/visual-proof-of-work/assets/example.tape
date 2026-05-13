# example.tape — canonical VHS template for visual-proof-of-work.
#
# Run with:   vhs example.tape
# Output:     proof.gif in the current directory.
#
# Defaults below render well inline on GitHub and read on mobile.
# Override any Set line for a different aesthetic, but keep the
# TypingSpeed in the 30–60ms range — faster looks fake, slower bores.

Output proof.gif

Set Width 1000
Set Height 600
Set FontSize 18
Set TypingSpeed 40ms
Set Theme "Dracula"

# --- intro ---------------------------------------------------------
Type "git rev-parse --short HEAD"
Enter
Sleep 600ms

# --- the actual work ----------------------------------------------
# Prefer Wait /<regex>/ over Sleep when there is a clear success
# marker — Wait proves the command finished, Sleep only proves time
# passed.

Type "npm test"
Enter
Wait /passed|success|ok|✓/

# --- afterword (optional) -----------------------------------------
Type "echo 'work verified at' $(date -u +%Y-%m-%dT%H:%M:%SZ)"
Enter
Sleep 1s
