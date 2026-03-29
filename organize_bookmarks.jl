# SPDX-License-Identifier: PMPL-1.0-or-later
# organize_bookmarks.jl — Categorize Firefox+Edge bookmarks into themed Markdown
# Migrated from Python (organize_bookmarks.py)

const THEMES = Dict{String, Vector{String}}(
    "Tech & Programming" => ["github", "programming", "docker", "server", "code", "dev", "tech", "node", "python", "rust", "npm", "stack", "api", "web", "cloud", "aws", "google", "microsoft", "apple", "app", "software"],
    "Linux & OS" => ["fedora", "linux", "ubuntu", "debian", "kernel", "cli", "shell", "bash", "terminal", "desktop", "os", "system", "config"],
    "News & Finance" => ["news", "breaking", "msn", "trump", "politics", "economy", "market", "finance", "bank", "money", "stock", "crypto", "bitcoin", "business", "invest", "trading"],
    "Psychology & Growth" => ["psychology", "mental", "self", "growth", "happiness", "manipulation", "relationships", "advice", "life", "wellness", "mindset", "success", "productivity"],
    "Art, Culture & Design" => ["art", "artist", "design", "museum", "culture", "style", "creative", "photo", "music", "history", "philosophy", "books", "writing"],
    "Lifestyle & Health" => ["food", "cooking", "recipe", "health", "fitness", "yoga", "travel", "holiday", "home", "garden", "shopping", "amazon", "buy", "deal"],
    "Education & Career" => ["learn", "course", "study", "university", "school", "job", "career", "resume", "cv", "interview", "skills", "training"],
    "Media & Social" => ["youtube", "video", "tv", "movie", "entertainment", "facebook", "twitter", "x.com", "instagram", "reddit", "watch", "podcast"],
)

"""Categorize a bookmark line by matching keywords against themes."""
function categorize(line::AbstractString)::String
    line_lower = lowercase(line)
    for (theme, keywords) in THEMES
        if any(kw -> occursin(kw, line_lower), keywords)
            return theme
        end
    end
    return "Uncategorized"
end

function main()
    all_bookmarks = Dict{String, Vector{String}}()

    for path in ["/tmp/firefox_bookmarks.txt", "/tmp/edge_bookmarks.txt"]
        isfile(path) || continue
        for line in eachline(path)
            stripped = strip(line)
            isempty(stripped) && continue
            theme = categorize(stripped)
            push!(get!(all_bookmarks, theme, String[]), stripped)
        end
    end

    sorted_themes = sort(collect(filter(t -> t != "Uncategorized", keys(all_bookmarks))))
    haskey(all_bookmarks, "Uncategorized") && push!(sorted_themes, "Uncategorized")

    repos_dir = get(ENV, "REPOS_DIR", "/var/mnt/eclipse/repos")
    outpath = joinpath(repos_dir, "organized_bookmarks.md")

    open(outpath, "w") do f
        println(f, "# Refined Organized Bookmarks\n")
        for theme in sorted_themes
            items = sort(unique(all_bookmarks[theme]))
            println(f, "## $theme")
            for item in items
                parts = split(item, "|"; limit=2)
                if length(parts) == 2
                    println(f, "- [$(parts[1])]($(parts[2]))")
                else
                    println(f, "- $item")
                end
            end
            println(f)
        end
    end

    println("Success: $outpath generated.")
end

main()
