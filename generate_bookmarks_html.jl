# SPDX-License-Identifier: PMPL-1.0-or-later
# generate_bookmarks_html.jl — Generate Netscape bookmark HTML from categorized bookmarks
# Migrated from Python (generate_bookmarks_html.py)

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

"""Escape HTML special characters."""
function html_escape(s::AbstractString)::String
    s = replace(s, "&" => "&amp;")
    s = replace(s, "<" => "&lt;")
    s = replace(s, ">" => "&gt;")
    s = replace(s, "\"" => "&quot;")
    return s
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
    outpath = joinpath(repos_dir, "organized_bookmarks.html")

    open(outpath, "w") do f
        println(f, "<!DOCTYPE NETSCAPE-Bookmark-file-1>")
        println(f, "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">")
        println(f, "<TITLE>Bookmarks</TITLE>")
        println(f, "<H1>Bookmarks</H1>")
        println(f, "<DL><p>")

        for theme in sorted_themes
            items = sort(unique(all_bookmarks[theme]))
            println(f, "    <DT><H3>$theme</H3>")
            println(f, "    <DL><p>")
            for item in items
                parts = split(item, "|"; limit=2)
                if length(parts) == 2
                    name = html_escape(String(parts[1]))
                    url = String(parts[2])
                    println(f, "        <DT><A HREF=\"$url\">$name</A>")
                end
            end
            println(f, "    </DL><p>")
        end

        println(f, "</DL><p>")
    end

    println("Success: $outpath generated.")
end

main()
