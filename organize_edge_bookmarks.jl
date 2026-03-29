# SPDX-License-Identifier: PMPL-1.0-or-later
# organize_edge_bookmarks.jl — Categorize bookmarks and write Edge Bookmarks JSON
# Migrated from Python (organize_edge_bookmarks.py)

using JSON3
using UUIDs
using Dates

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

"""Chrome/Edge timestamp: microseconds since Jan 1, 1601."""
function chrome_timestamp(dt::DateTime)::String
    epoch_1601 = DateTime(1601, 1, 1)
    diff_seconds = Dates.value(dt - epoch_1601) / 1000  # ms → s
    return string(round(Int64, diff_seconds * 1_000_000))
end

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

    now_ts = chrome_timestamp(now())
    current_id = Ref(4)

    function next_id()
        id = current_id[]
        current_id[] += 1
        return string(id)
    end

    bookmark_bar_children = []

    sorted_themes = sort(collect(filter(t -> t != "Uncategorized", keys(all_bookmarks))))
    haskey(all_bookmarks, "Uncategorized") && push!(sorted_themes, "Uncategorized")

    for theme in sorted_themes
        items = sort(unique(all_bookmarks[theme]))
        children = []
        for item in items
            parts = split(item, "|"; limit=2)
            if length(parts) == 2
                push!(children, Dict(
                    "date_added" => now_ts,
                    "date_last_used" => "0",
                    "guid" => string(uuid4()),
                    "id" => next_id(),
                    "name" => parts[1],
                    "type" => "url",
                    "url" => parts[2],
                ))
            end
        end
        push!(bookmark_bar_children, Dict(
            "date_added" => now_ts,
            "date_last_used" => "0",
            "guid" => string(uuid4()),
            "id" => next_id(),
            "name" => theme,
            "type" => "folder",
            "children" => children,
        ))
    end

    output = Dict(
        "checksum" => "",
        "roots" => Dict(
            "bookmark_bar" => Dict(
                "children" => bookmark_bar_children,
                "date_added" => now_ts,
                "date_last_used" => "0",
                "guid" => string(uuid4()),
                "id" => "1",
                "name" => "Favorites Bar",
                "type" => "folder",
            ),
            "other" => Dict("children" => [], "date_added" => "0", "date_last_used" => "0", "guid" => string(uuid4()), "id" => "2", "name" => "Other Favorites", "type" => "folder"),
            "synced" => Dict("children" => [], "date_added" => "0", "date_last_used" => "0", "guid" => string(uuid4()), "id" => "3", "name" => "Mobile Favorites", "type" => "folder"),
        ),
        "version" => 1,
    )

    outpath = expanduser("~/.var/app/com.microsoft.EdgeDev/config/microsoft-edge-dev/Default/Bookmarks")
    open(outpath, "w") do f
        JSON3.pretty(f, output; allow_inf=true)
    end

    println("Success: Edge Bookmarks file overwritten.")
end

main()
