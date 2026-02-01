export const PreCommitHook = async ({ project, client, $, directory, worktree }) => {
  return {
    "file.edited": async ({ filePath }) => {
      // Only run on files that are tracked by git
      try {
        await $`git ls-files --error-unmatch ${filePath}`.quiet()
      } catch {
        // File is not tracked by git, skip
        return
      }

      // Check if pre-commit is installed
      try {
        await $`which pre-commit`.quiet()
      } catch {
        await client.app.log({
          service: "pre-commit-hook",
          level: "warn",
          message: "pre-commit not found in PATH, skipping",
        })
        return
      }

      // Run pre-commit on the specific file
      try {
        await client.app.log({
          service: "pre-commit-hook",
          level: "info",
          message: `Running pre-commit on ${filePath}`,
        })

        await $`pre-commit run --files ${filePath}`.cwd(directory)

        await client.app.log({
          service: "pre-commit-hook",
          level: "info",
          message: `pre-commit completed for ${filePath}`,
        })
      } catch (error) {
        await client.app.log({
          service: "pre-commit-hook",
          level: "error",
          message: `pre-commit failed for ${filePath}: ${error.message}`,
        })
      }
    },
  }
}
