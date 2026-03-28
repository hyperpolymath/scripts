defmodule RepoAuditor.RuleEngine do
  @moduledoc """
  AI-driven repository auditor enforcing hyperpolymath mandates.
  """

  @cruft_dirs ["target", "node_modules", "_build", "dist", "deps", "dist-newstyle"]

  @doc "Main entry point for an AI agent to analyze and fix a repo."
  def run(repo_path, auto_fix \\ false) do
    IO.puts("🔍 Auditing: #{repo_path}")
    
    results = [
      check_cruft(repo_path, auto_fix),
      enforce_containerfile(repo_path, auto_fix),
      detect_runtime_violations(repo_path),
      detect_language_violations(repo_path),
      enforce_justfile_arch(repo_path, auto_fix)
    ]

    # Return structured data for the AI to parse and act upon
    %{repo: repo_path, findings: Enum.reject(results, &is_nil/1)}
  end

  # ==========================================
  # 1. CRUFT CLEANUP (Fully Automated)
  # ==========================================
  defp check_cruft(repo_path, auto_fix) do
    found_cruft = 
      @cruft_dirs
      |> Enum.map(&Path.join(repo_path, &1))
      |> Enum.filter(&File.exists?/1)

    if found_cruft != [] do
      if auto_fix do
        Enum.each(found_cruft, &File.rm_rf!/1)
        %{category: :cruft, status: :fixed, details: "Purged: #{inspect(found_cruft)}"}
      else
        %{category: :cruft, status: :violation, details: "Found cruft: #{inspect(found_cruft)}"}
      end
    end
  end

  # ==========================================
  # 2. CONTAINER STANDARDS (Fully Automated)
  # ==========================================
  defp enforce_containerfile(repo_path, auto_fix) do
    dockerfile = Path.join(repo_path, "Dockerfile")
    containerfile = Path.join(repo_path, "Containerfile")

    if File.exists?(dockerfile) do
      if auto_fix do
        File.rename!(dockerfile, containerfile)
        %{category: :container_standards, status: :fixed, details: "Renamed Dockerfile to Containerfile"}
      else
        %{category: :container_standards, status: :violation, details: "Dockerfile found. Must use Containerfile."}
      end
    end
  end

  # ==========================================
  # 3. RUNTIME VIOLATIONS (Semi-Automated)
  # ==========================================
  defp detect_runtime_violations(repo_path) do
    has_npm = File.exists?(Path.join(repo_path, "package-lock.json"))
    has_bun = File.exists?(Path.join(repo_path, "bun.lockb"))

    cond do
      has_npm -> %{category: :runtime, status: :violation, details: "NPM detected. Must migrate to Deno (or Bun as fallback)."}
      has_bun -> %{category: :runtime, status: :warning, details: "Bun detected. Deno is the preferred top-level runtime."}
      true -> nil
    end
  end

  # ==========================================
  # 4. LANGUAGE STACKS (Manual / AI-Assisted)
  # ==========================================
  defp detect_language_violations(repo_path) do
    ts_files = Path.wildcard(Path.join(repo_path, "**/*.ts"))
    py_files = Path.wildcard(Path.join(repo_path, "**/*.py"))

    violations = []
    violations = if ts_files != [], do: ["TypeScript found (Migrate to ReScript)" | violations], else: violations
    violations = if py_files != [], do: ["Python found (Migrate to Julia)" | violations], else: violations

    if violations != [] do
      %{category: :language, status: :violation, requires: :manual_translation, details: violations}
    end
  end

  # ==========================================
  # 5. AUTOMATION STANDARDS (Automated)
  # ==========================================
  defp enforce_justfile_arch(repo_path, auto_fix) do
    justfile = Path.join(repo_path, "Justfile")
    justfile_alt = Path.join(repo_path, "justfile")
    target = if File.exists?(justfile), do: justfile, else: (if File.exists?(justfile_alt), do: justfile_alt, else: nil)

    if target do
      content = File.read!(target)
      unless String.contains?(content, "riscv64") or String.contains?(content, "multi-arch") do
        if auto_fix do
          append_riscv_recipe(target)
          %{category: :automation, status: :fixed, details: "Injected RISC-V/multi-arch recipe into Justfile"}
        else
          %{category: :automation, status: :violation, details: "Justfile missing RISC-V or multi-arch support."}
        end
      end
    else
      %{category: :automation, status: :violation, details: "No Justfile found in repository."}
    end
  end

  defp append_riscv_recipe(file) do
    recipe = """
    
    # [AUTO-GENERATED] Multi-arch / RISC-V target
    build-riscv:
    \t@echo "Building for RISC-V..."
    \tcross build --target riscv64gc-unknown-linux-gnu
    """
    File.write!(file, recipe, [:append])
  end
end

# Example usage when run as a script:
# Repos to audit
repos_root = "/var$REPOS_DIR"

File.ls!(repos_root)
|> Enum.map(&Path.join(repos_root, &1))
|> Enum.filter(&File.dir?/1)
|> Enum.reject(&String.starts_with?(Path.basename(&1), "."))
|> Enum.each(fn repo ->
  RepoAuditor.RuleEngine.run(repo, System.get_env("AUTO_FIX") == "true")
end)
